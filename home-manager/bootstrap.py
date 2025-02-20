# From a working Nix install, this script sets up Home-Manager.
# First, a symlink to flake.nix is created in ~/.config/home-manager
# Next, the

def generate_machine_specific(user, state_version):
    if user == 'root':
        home = '/root'
    else:
        home = f'/home/{user}'
    return """
    {
        home = {
            username = "{user}";
            homeDirectory = "{home}";
            stateVersion = "{state_version}";
        };
    }
    """.format(user=user, home=home, state_version=state_version)

