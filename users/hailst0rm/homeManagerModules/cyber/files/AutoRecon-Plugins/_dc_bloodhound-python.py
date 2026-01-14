from autorecon.plugins import ServiceScan

class BloodhoundPython(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'bloodhound-python'
		self.tags = ['default', 'safe', 'ldap', 'auth']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])

	def check(self):
		if which('bloodhound-python') is None:
			self.error('The program bloodhound-python could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('domain') and self.get_global('username'):
			domain = self.get_global('domain')
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('bloodhound-python -c all --zip -w 40 -u' + username + '-p ' + password + ' -d ' + domain + ' -ns {address}', outfile='bloodhound-python.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('bloodhound-python -c all --zip -w 40 -u' + username + '--hashes ' + nthash + ' -d ' + domain + ' -ns {address}', outfile='bloodhound-python.txt')
		else:
			self.error('bloodhound-python requires domain and username global options to be set.')
