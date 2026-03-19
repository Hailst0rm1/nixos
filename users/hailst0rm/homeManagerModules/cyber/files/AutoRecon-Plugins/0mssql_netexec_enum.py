from autorecon.plugins import ServiceScan
from shutil import which

class NetExec_MSSQLEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec MSSQLEnum"
		self.tags = ['safe', 'databases', 'mssql', 'auth']

	def configure(self):
		self.match_service_name(['^mssql', r'^ms\-sql'])

	def check(self):
		if which('nxc') is None:
			self.error('The program nxc could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('ticket'):
			await service.execute('nxc mssql {address} --use-kcache -k -M mssql_priv', outfile='netexec_enum_privesc.txt')
			await service.execute('nxc mssql {address} --use-kcache -k --rid-brute', outfile='netexec_enum_rid_brute.txt')
			await service.execute('nxc mssql {address} --use-kcache -k -M enum_links', outfile='netexec_enum_links.txt')
			await service.execute('nxc mssql {address} --use-kcache -k -M enum_impersonate', outfile='netexec_enum_impersonate.txt')
			await service.execute('nxc mssql {address} --use-kcache -k -M enum_logins', outfile='netexec_enum_logins.txt')
		elif self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('nxc mssql {address} -u ' + username + ' -p ' + password + ' -M mssql_priv', outfile='netexec_enum_privesc.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -p ' + password + ' --rid-brute', outfile='netexec_enum_rid_brute.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -p ' + password + ' -M enum_links', outfile='netexec_enum_links.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -p ' + password + ' -M enum_impersonate', outfile='netexec_enum_impersonate.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -p ' + password + ' -M enum_logins', outfile='netexec_enum_logins.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('nxc mssql {address} -u ' + username + ' -H ' + nthash + ' -M mssql_priv', outfile='netexec_enum_privesc.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -H ' + nthash + ' --rid-brute', outfile='netexec_enum_rid_brute.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -H ' + nthash + ' -M enum_links', outfile='netexec_enum_links.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -H ' + nthash + ' -M enum_impersonate', outfile='netexec_enum_impersonate.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' -H ' + nthash + ' -M enum_logins', outfile='netexec_enum_logins.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('nxc mssql {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -M mssql_priv', outfile='netexec_enum_privesc.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} --rid-brute', outfile='netexec_enum_rid_brute.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -M enum_links', outfile='netexec_enum_links.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -M enum_impersonate', outfile='netexec_enum_impersonate.txt')
				await service.execute('nxc mssql {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -M enum_logins', outfile='netexec_enum_logins.txt')
		else:
			self.error('nxc requires username global option to be set.')
