from autorecon.plugins import ServiceScan
from shutil import which

class ADPulse(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'ADPulse'
		self.tags = ['safe', 'ldap', 'auth', 'active-directory']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])
		self.run_once(True)

	def check(self):
		if which('adpulse') is None:
			self.error('The program ADPulse could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username') and self.get_global('domain'):
			username = self.get_global('username')
			domain = self.get_global('domain')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('adpulse --domain ' + domain + ' --user ' + username + ' --password ' + password + ' --dc-ip {address} --output-dir {scandir} --report all', outfile='adpulse.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('adpulse --domain ' + domain + ' --user ' + username + ' --hash ' + nthash + ' --dc-ip {address} --output-dir {scandir} --report all', outfile='adpulse.txt')
		else:
			self.error('ADPulse requires domain and username global options to be set.')
