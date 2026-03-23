import re
from autorecon.plugins import ServiceScan
from shutil import which

class BloodhoundPython(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'bloodhound-python'
		self.tags = ['safe', 'ldap', 'auth']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])

	def check(self):
		if which('bloodhound-python') is None:
			self.error('The program bloodhound-python could not be found. Make sure it is installed.')
			return False

	def _resolve_domain(self, address):
		"""Resolve an IP to its domain name via /etc/hosts.

		If the IP has multiple entries, prefer the one without a hostname prefix
		(i.e. the shortest domain - the one with fewest dots that has at least one dot).
		Examples:
		  172.16.228.160 -> rdc02, rdc02.comply.com, comply.com => comply.com
		  172.16.228.165 -> CDC07.ops.comply.com, CDC07, ops.comply.com => ops.comply.com
		"""
		if not re.match(r'^\d+\.\d+\.\d+\.\d+$', address):
			return address

		names = []
		try:
			with open('/etc/hosts', 'r') as f:
				for line in f:
					line = line.strip()
					if not line or line.startswith('#'):
						continue
					parts = line.split()
					if parts[0] == address:
						names.extend(parts[1:])
		except (IOError, OSError):
			return None

		if not names:
			return None

		# Filter to entries that contain at least one dot (domain names, not bare hostnames)
		domains = [n for n in names if '.' in n]
		if not domains:
			return None

		# Pick the domain with the fewest parts (e.g. comply.com over rdc02.comply.com)
		domains.sort(key=lambda n: n.count('.'))
		return domains[0]

	async def run(self, service):
		dcip = self.get_global('dcip')
		ns = dcip if dcip else '{address}'
		domain = self.get_global('domain')
		address = service.target.address

		if not self.get_global('username'):
			self.error('bloodhound-python requires username global option to be set.')
			return

		username = self.get_global('username')

		# Resolve address to domain name for -d flag (bloodhound-python requires a domain, not an IP)
		resolved = self._resolve_domain(address)
		if resolved:
			d_value = resolved
		elif domain:
			d_value = domain
		else:
			d_value = '{address}'

		# Build user argument: user@domain if domain is set
		if domain:
			user_arg = username + '@' + domain
		else:
			user_arg = username

		if self.get_global('ticket'):
			await service.execute('cd "{scandir}" && bloodhound-python -c all --zip -w 40 -u ' + user_arg + ' -k -no-pass -d ' + d_value + ' -ns ' + ns, outfile='bloodhound-python.txt')
		else:
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('cd "{scandir}" && bloodhound-python -c all --zip -w 40 -u ' + user_arg + ' -p ' + password + ' -d ' + d_value + ' -ns ' + ns, outfile='bloodhound-python.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('cd "{scandir}" && bloodhound-python -c all --zip -w 40 -u ' + user_arg + ' --hashes :' + nthash + ' -d ' + d_value + ' -ns ' + ns, outfile='bloodhound-python.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('cd "{scandir}" && bloodhound-python -c all --zip -w 40 -u ' + user_arg + ' -aesKey ' + aeskey + ' -d ' + d_value + ' -ns ' + ns, outfile='bloodhound-python.txt')
