import yaml 
import json
from os.path import expanduser

def pprint(o):
    print json.dumps(o, indent=4, sort_keys=True)

class yamlConfig(object):
    def __init__(self, filename="server-config.yaml"):
        with open(filename, "r") as yml:
            try:
                self.data = yaml.load(yml)
            except yaml.YAMLError as exc: 
                print(exc)

    @staticmethod
    def add_ssh_item(host):
        out = ""
        # hack fix so that port doesnt go first
        for key, value in iter(sorted(host.iteritems())):
            if key.lower() == "tags": continue
            out += ("%s %s\n".encode("utf-8") % (key.capitalize(), value))
        out += "\n"
        return out

    @staticmethod
    def add_ansible_item(tag, hosts):
        out = "[%s]\n" % tag
        for host in hosts:
            out += host + "\n"
        out += "\n"
        return out

    def ssh_config(self):
        out = ""
        for host in self.data:
            out += self.add_ssh_item(host)

        return out

    def ansible_config(self):
        out = ""

        data = dict()

        for host in self.data:
            # create tags key if it doesnt exist
            if "tags" not in host:
                host["tags"] = []

            # convert to array if it isn't one
            if not isinstance(host["tags"], list):
                host["tags"] = [host["tags"]]
            
            # add host name as a tag
            if host["host"] not in host["tags"]:
                host["tags"].append(host["host"])

            for tag in host["tags"]:
                data.setdefault(tag, []).append(host["host"]) 

        for tag, hosts in iter(sorted(data.iteritems())):
            out += self.add_ansible_item(tag, hosts)

        return out            

    def pprint(self):
        pprint (self.data)

    def write_ssh_config(self):
        f = open(expanduser("~/.ssh/config"), "w")
        f.write(self.ssh_config())
        f.close    

    def write_ansible_config(self):
        f = open("hosts", "w")
        f.write(self.ansible_config())
        f.close

test = yamlConfig()

test.write_ansible_config()
test.write_ssh_config()
