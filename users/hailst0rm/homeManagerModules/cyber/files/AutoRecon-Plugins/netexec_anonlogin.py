from autorecon.plugins import ServiceScan 

class NetExec_AnonLogin(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec AnonLogin"
		self.tags = ['default', 'safe', 'smb', 'active-directory']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', [139, 445])
		self.run_once(True)

	async def run(self, service):
		await service.execute("nxc smb {address} -u '' -p ''", outfile='netexec_anonlogin.txt')
