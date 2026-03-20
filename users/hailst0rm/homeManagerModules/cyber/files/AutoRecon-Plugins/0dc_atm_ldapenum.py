from autorecon.plugins import ServiceScan
from shutil import which

class ATM_LDAPEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'atm-enum-ldap'
		self.tags = ['safe', 'auth', 'active-directory', 'ldap']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])
		self.run_once(True)

	def check(self):
		if which('atm') is None:
			self.error('The program atm could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('ticket'):
			await service.execute('atm enum ldap {address} --use-kcache -o "{scandir}"', outfile='atm-enum-ldap.txt')
		elif self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('atm enum ldap {address} -u ' + username + ' -p ' + password + ' -o "{scandir}"', outfile='atm-enum-ldap.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('atm enum ldap {address} -u ' + username + ' -H ' + nthash + ' -o "{scandir}"', outfile='atm-enum-ldap.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('atm enum ldap {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -o "{scandir}"', outfile='atm-enum-ldap.txt')
		else:
			self.error('atm enum ldap requires username global option to be set.')
