from autorecon.plugins import ServiceScan

class SMBClient(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "SMBClient"
		self.tags = ['safe', 'smb', 'active-directory'] # Removed 'default' to inactivate
		# self.tags = ['default', 'safe', 'smb', 'active-directory']

	def configure(self):
		self.match_service_name(['^smb', r'^microsoft\-ds', '^netbios'])
		self.match_port('tcp', [139, 445])
		self.run_once(True)

	async def run(self, service):
		await service.execute('smbclient -L //{address} -N -I {address} 2>&1', outfile='smbclient.txt')
