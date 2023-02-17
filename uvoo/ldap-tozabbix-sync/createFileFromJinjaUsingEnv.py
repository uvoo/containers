from jinja2 import Template, StrictUndefined
import argparse
import os

parser = argparse.ArgumentParser(description='Create Zabbix screen from all of a host Items or Graphs.')
parser.add_argument('-t', '--template-file', required=True, type=str,
                    help='Jinja template file name path.')
args = parser.parse_args()

to_file=args.template_file.rsplit('.', 1)[0]

with open(args.template_file) as f_:
    template = Template(f_.read(), undefined=StrictUndefined)
txt = template.render(env=os.environ)
with open(to_file, 'w') as f_:
    f_.write(txt)
