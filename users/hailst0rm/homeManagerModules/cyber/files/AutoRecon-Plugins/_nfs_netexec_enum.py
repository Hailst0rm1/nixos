from autorecon.plugins import ServiceScan

class NetExec_NFSEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec NFS Enum"
		self.tags = ['default', 'safe', 'nfs']

	def configure(self):
		self.match_service_name(['^nfs', '^rpcbind'])

	def check(self):
		if which('nxc') is None:
			self.error('The program nxc could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		await service.execute('nxc nfs {address} --shares', outfile='netexec_enum_shares.txt')
		await service.execute('nxc nfs {address} --enum-shares', outfile='netexec_enum_spider.txt')
		await service.execute("nxc nfs {address} --ls '/'", outfile='netexec_enum_root_escape.txt')
