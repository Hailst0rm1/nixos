from autorecon.plugins import ServiceScan

class NetExec_DC_SMBEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'netexec_dc_smbenum'
		self.tags = ['default', 'safe', 'ldap', 'auth']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])

	def check(self):
		if which('netexec') is None:
			self.error('The program netexec could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' --shares', outfile='netexec_dc_smbenum_shares.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' --pass-pol', outfile='netexec_dc_smbenum_pass_pol.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' --users', outfile='netexec_dc_smbenum_users.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' --local-group', outfile='netexec_dc_smbenum_local_group.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' -M gpp_autologin', outfile='netexec_dc_smbenum_gpp_autologin.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' -M gpp_password', outfile='netexec_dc_smbenum_gpp_password.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' --shares', outfile='netexec_dc_smbenum_shares.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' --pass-pol', outfile='netexec_dc_smbenum_pass_pol.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' --users', outfile='netexec_dc_smbenum_users.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' --local-group', outfile='netexec_dc_smbenum_local_group.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' -M gpp_autologin', outfile='netexec_dc_smbenum_gpp_autologin.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' -M gpp_password', outfile='netexec_dc_smbenum_gpp_password.txt')
		else:
			self.error('netexec requires username global option to be set.')