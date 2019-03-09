import docker
import time
import os
import subprocess

project_name = 'keepitsimple'
image_name = 'lvo.dev/' + project_name
network_name = project_name

client = docker.from_env()

name = 'keepitsimple_' + str(time.time())

print "Running new container"
new_container = client.containers.run(
    image_name,
    name=name,
    detach=True,
    network=network_name
)

print "Waiting"
time.sleep(20)


network = client.networks.get(network_name)
raw_ip = network.attrs['Containers'][new_container.id]['IPv4Address']
ip = raw_ip[:raw_ip.index('/')]

content_tpl = "upstream {project} {{\n    server {ip};\n}}"
filename = os.environ['UPSTREAMS_LOCATION'].format(project=project_name)
with open(filename, 'w') as f:
    f.write(content_tpl.format(project=project_name, ip=ip))

print "Reloading Nginx"
subprocess.check_output(['sudo', 'systemctl', 'reload', 'nginx'])

print "Wainting"
time.sleep(20)

print "Removing old containers"
filters = {'name': '^keepitsimple_[0-9.]+$'}
for container in client.containers.list(all=True, filters=filters):
    if container.name == name:  # Don't remove just created container !
        continue

    container.stop()
    container.remove()
