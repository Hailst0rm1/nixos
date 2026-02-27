from autorecon.plugins import ServiceScan 

class NetExec_FTPAnon(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec FTPAnon"
		self.tags = ['default', 'safe', 'ftp']

	def configure(self):
		self.match_service_name(['^ftp', '^ftps'])
		self.match_port('tcp', 21)
		self.run_once(True)

	async def run(self, service):
		await service.execute("nxc ftp {address} -u 'anonymous' -p '' --ls", outfile='netexec_ftp_anonlogin.txt')
