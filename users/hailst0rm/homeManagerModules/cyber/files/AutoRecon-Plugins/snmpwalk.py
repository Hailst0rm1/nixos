from autorecon.plugins import ServiceScan

class SNMPWalkExtended(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "SNMPWalkExtended"
		self.tags = ['default', 'safe', 'snmp']

	def configure(self):
		self.match_service_name('^snmp')
		self.match_port('udp', 161)
		self.run_once(True)

	async def run(self, service):
		await service.execute('snmpwalk -c public -v 1 {address} NET-SNMP-EXTEND-MIB::nsExtendOutputFull 2>&1', outfile='{protocol}_{port}_snmp_snmpwalk_extended.txt')
