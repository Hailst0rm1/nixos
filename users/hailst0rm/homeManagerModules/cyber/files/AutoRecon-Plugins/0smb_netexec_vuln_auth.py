from autorecon.plugins import ServiceScan

class NetExec_Common_Vuln_Auth(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec Common Vulns Authenticated"
		self.tags = ['safe', 'smb', 'active-directory', 'auth']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', 445)
		self.run_once(True)

	async def run(self, service):
		if self.get_global('ticket'):
			await service.execute('netexec smb {address} --use-kcache -k -M nopac -M ntlm_reflection', outfile='netexec_vuln_auth.txt')
		elif self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('netexec smb {address} -u ' + username + ' -p ' + password + ' -M nopac -M ntlm_reflection', outfile='netexec_vuln_auth.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('netexec smb {address} -u ' + username + ' -H ' + nthash + ' -M nopac -M ntlm_reflection', outfile='netexec_vuln_auth.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('netexec smb {address} -u ' + username + ' --aesKey ' + aeskey + ' --kdcHost {address} -M nopac -M ntlm_reflection', outfile='netexec_vuln_auth.txt')
		else:
			self.error('netexec requires username global option to be set.')
