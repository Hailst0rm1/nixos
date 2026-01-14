from autorecon.plugins import ServiceScan

class NetExec_Common_Vuln(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "NetExec Common Vulns"
		self.tags = ['default', 'safe', 'smb', 'active-directory']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', 445)
		self.run_once(True)

	async def run(self, service):
		await service.execute("nxc smb {address} -u '' -p '' -M ms17-010 -M zerologon -M printnightmare -M smbghost -M coerce_plus", outfile='netexec_common_vuln.txt')
