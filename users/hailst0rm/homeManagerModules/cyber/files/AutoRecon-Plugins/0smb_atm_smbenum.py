from autorecon.plugins import ServiceScan
from shutil import which

class ATM_SMBEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'atm-enum-smb'
		self.tags = ['default', 'safe', 'smb', 'active-directory']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', 445)
		self.run_once(True)

	def check(self):
		if which('atm') is None:
			self.error('The program atm could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		domain = self.get_global('domain')
		d = ' -d ' + domain if domain else ''
		dcip = self.get_global('dcip')
		k = ' --kdcHost ' + dcip if dcip else ''

		if self.get_global('ticket'):
			await service.execute('atm enum smb {address} --use-kcache' + d + k + ' -o "{scandir}"', outfile='atm-enum-smb.txt')
		elif self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('atm enum smb {address} -u ' + username + ' -p ' + password + d + k + ' -o "{scandir}"', outfile='atm-enum-smb.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('atm enum smb {address} -u ' + username + ' -H ' + nthash + d + k + ' -o "{scandir}"', outfile='atm-enum-smb.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('atm enum smb {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address}' + d + ' -o "{scandir}"', outfile='atm-enum-smb.txt')
		else:
			await service.execute('atm enum smb {address} -o "{scandir}"', outfile='atm-enum-smb.txt')
