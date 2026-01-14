from autorecon.plugins import ServiceScan

class ATMRoast(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'atm-roast'
		self.tags = ['default', 'safe', 'ldap', 'auth']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])

	def check(self):
		if which('atm') is None:
			self.error('The program atm could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('atm roast {address} -u' + username + '-p ' + password, outfile='atm-roast.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('atm roast {address} -u' + username + '-H ' + nthash, outfile='atm-roast.txt')
		else:
			self.error('atm requires username global option to be set.')
