from autorecon.plugins import ServiceScan
from shutil import which

class ATM_NFSEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'atm-enum-nfs'
		self.tags = ['default', 'safe', 'nfs']

	def configure(self):
		self.match_service_name(['^nfs', '^rpcbind'])

	def check(self):
		if which('atm') is None:
			self.error('The program atm could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		await service.execute('atm enum nfs {address} -o "{scandir}"', outfile='atm-enum-nfs.txt')
