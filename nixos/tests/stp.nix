import ./make-test.nix ({ pkgs, lib, ... }:

let
  stp = true;
  kernel_package = "linuxPackages_4_7";

in {
  name = "stp";

  nodes = {

    server =
      { config, pkgs, ... }: {
        boot.kernelPackages = pkgs.${kernel_package};
        virtualisation.vlans = [ 1 2 ];
        networking.firewall.enable = false;
        networking.interfaces = {
          eth1 = lib.mkOverride 0 {};
          eth2 = lib.mkOverride 0 {};
        };

        containers.networkaccess = {
          autoStart = true;
          interfaces = [ "eth1" "eth2" ];
          config = { config, pkgs, ... }: {
            environment.systemPackages = [ pkgs.bridge-utils ];
            networking.localCommands = ''
              ip link add br0 type bridge
              ip addr add 10.0.0.1/8 dev br0
              ip link set br0 up
              ip link set eth1 master br0
              ip link set eth1 up
              ip link set eth2 master br0
              ip link set eth2 up
              ${pkgs.bridge-utils}/bin/brctl show
              ${pkgs.bridge-utils}/bin/brctl stp br0 on
            '';
          };
        };
      };

    client =
      { config, pkgs, ... }: {
        boot.kernelPackages = pkgs.${kernel_package};
        environment.systemPackages = [ pkgs.bridge-utils ];
        virtualisation.vlans = [ 1 2 ];
        networking.firewall.enable = false;
        networking.bridges = { br0 = { interfaces = [ "eth1" "eth2" ]; rstp = stp; }; };
        networking.interfaces = {
          br0 = { ip4 = [ { address = "10.0.0.7"; prefixLength = 8; } ]; };
          eth1 = lib.mkOverride 0 {};
          eth2 = lib.mkOverride 0 {};
        };
      };

  };

  testScript = ''
    startAll;

    $server->waitForUnit("default.target");
    $server->waitForUnit("container\@networkaccess");
    $client->waitForUnit("default.target");

    subtest "both connected", sub {
      $client->succeed("ping -w 30 -c 1 10.0.0.1 >&2");
    };

    subtest "only eth1 connected", sub {
      $client->block(2);
      $client->succeed("ping -w 30 -c 1 10.0.0.1 >&2");
      $client->unblock(2);
    };

    subtest "only eth2 connected", sub {
      $client->block(1);
      $client->succeed("ping -w 30 -c 1 10.0.0.1 >&2");
      $client->unblock(1);
    };
  '';
})
