from autorecon.plugins import ServiceScan

class NetExec_Enum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec Enum"
		self.tags = ['default', 'safe', 'smb', 'active-directory', 'auth']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', 445)
		self.run_once(True)

	def check(self):
		if which('netexec') is None:
			self.error('The program netexec could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' -M coerce_plus', outfile='netexec_enum_coerce_plus.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --shares', outfile='netexec_enum_shares.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --filter-shares "read,write"', outfile='netexec_enum_shares-rw.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --filter-shares "read"', outfile='netexec_enum_shares-r.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --filter-shares "write"', outfile='netexec_enum_shares-w.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' -M spider_plus {scandir}/netexec_spider.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --disks', outfile='netexec_enum_disks.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --users', outfile='netexec_enum_users.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --rid-brute', outfile='netexec_enum_rid_brute.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --local-group', outfile='netexec_enum_local_groups.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' -M enum_av', outfile='netexec_enum_av.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --reg-sessions', outfile='netexec_enum_sessions.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' --tasklist', outfile='netexec_enum_tasklist.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' -M reg-winlogon', outfile='netexec_enum_reg_winlogon.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' -M ioxidresolver', outfile='netexec_enum_ioxidresolver.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' -M coerce_plus', outfile='netexec_enum_coerce_plus.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --shares', outfile='netexec_enum_shares.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --filter-shares "read,write"', outfile='netexec_enum_shares-rw.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --filter-shares "read"', outfile='netexec_enum_shares-r.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --filter-shares "write"', outfile='netexec_enum_shares-w.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' -M spider_plus {scandir}/netexec_spider.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --disks', outfile='netexec_enum_disks.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --users', outfile='netexec_enum_users.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --rid-brute', outfile='netexec_enum_rid_brute.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --local-group', outfile='netexec_enum_local_groups.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' -M enum_av', outfile='netexec_enum_av.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --reg-sessions', outfile='netexec_enum_sessions.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' --tasklist', outfile='netexec_enum_tasklist.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' -M reg-winlogon', outfile='netexec_enum_reg_winlogon.txt')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' -M ioxidresolver', outfile='netexec_enum_ioxidresolver.txt')
		else:
			await service.execute("nxc smb {address} -u '' -p '' -M coerce_plus", outfile='netexec_enum_coerce_plus.txt')
