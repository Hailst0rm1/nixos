from autorecon.plugins import ServiceScan
from shutil import which

class ATM_MSSQLEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'atm-enum-mssql'
		self.tags = ['safe', 'databases', 'mssql', 'auth']

	def configure(self):
		self.match_service_name(['^mssql', r'^ms\-sql'])

	def check(self):
		if which('atm') is None:
			self.error('The program atm could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('ticket'):
			await service.execute('atm enum mssql {address} --use-kcache -o "{scandir}"', outfile='atm-enum-mssql.txt')
		elif self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('atm enum mssql {address} -u ' + username + ' -p ' + password + ' -o "{scandir}"', outfile='atm-enum-mssql.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('atm enum mssql {address} -u ' + username + ' -H ' + nthash + ' -o "{scandir}"', outfile='atm-enum-mssql.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('atm enum mssql {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -o "{scandir}"', outfile='atm-enum-mssql.txt')
		else:
			self.error('atm enum mssql requires username global option to be set.')
