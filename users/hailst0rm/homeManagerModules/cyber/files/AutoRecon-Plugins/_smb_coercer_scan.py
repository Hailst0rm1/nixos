from autorecon.plugins import ServiceScan

class Coercer_Scan(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "Coercer Scan"
		self.tags = ['default', 'safe', 'smb', 'active-directory', 'auth']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', 445)
		self.run_once(True)

	def check(self):
		if which('coercer') is None:
			self.error('The program coercer could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('coercer scan --target-ip {address} -u ' + username + ' -p ' + password, outfile='coercer_scan.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('coercer scan --target-ip {address} -u ' + username + ' --hashes ' + nthash, outfile='coercer_scan.txt')
		else:
			self.error('coercer requires username global option to be set.')
