import ./make-test.nix ({ pkgs, lib, ... }:

let

in {
  name = "stp";

  nodes = {

    server =
      { config, pkgs, ... }: {
        virtualisation.vlans = [ 1 2 ];
        networking.firewall.enable = false;
        networking.bridges = { br0 = { interfaces = [ "eth1" "eth2" ]; rstp = true; }; };
        networking.interfaces = {
          br0 = { ip4 = [ { address = "10.0.0.1"; prefixLength = 8; } ]; };
          eth1 = lib.mkOverride 0 {};
          eth2 = lib.mkOverride 0 {};
        };
      };

    client =
      { config, pkgs, ... }: {
        environment.systemPackages = [ pkgs.bridge-utils ];
        virtualisation.vlans = [ 1 2 ];
        networking.firewall.enable = false;
        networking.bridges = { br0 = { interfaces = [ "eth1" "eth2" ]; rstp = true; }; };
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
