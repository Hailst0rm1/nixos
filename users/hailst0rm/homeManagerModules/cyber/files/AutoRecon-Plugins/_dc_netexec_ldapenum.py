from autorecon.plugins import ServiceScan

class NetExec_DC_LDAPEnum(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'NetExec DC LDAP Enum'
		self.tags = ['default', 'safe', 'auth', 'active-directory', 'ldap']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])
		self.run_once(True)

	def check(self):
		if which('nxc') is None:
			self.error('The program nxc could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --get-sid', outfile='netexec_dc_ldapenum_sid.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --pso', outfile='netexec_dc_ldapenum_pso.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --dc-list', outfile='netexec_dc_ldapenum_dc_list.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --find-delegation', outfile='netexec_dc_ldapenum_delegation.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --trusted-for-delegation', outfile='netexec_dc_ldapenum_unconstrained_delegation.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --groups "Backup Operators"', outfile='netexec_dc_ldapenum_backup_operators.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --groups "Domain Admins"', outfile='netexec_dc_ldapenum_domain_admins.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' --admin-count', outfile='netexec_dc_ldapenum_admin_count.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M get-desc-users', outfile='netexec_dc_ldapenum_get_desc_users.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M get-network -o ALL=true', outfile='netexec_dc_ldapenum_subnets.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M entra-id', outfile='netexec_dc_ldapenum_entra_id.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M obsolete', outfile='netexec_dc_ldapenum_obsolete.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M userPassword', outfile='netexec_dc_ldapenum_userPassword.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M unixUserPassword', outfile='netexec_dc_ldapenum_unixUserPassword.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -p ' + password + ' -M adcs', outfile='netexec_dc_ldapenum_adcs.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -p ' + password + ' -M pre2k', outfile='netexec_dc_ldapenum_pre2k.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --get-sid', outfile='netexec_dc_ldapenum_sid.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --pso', outfile='netexec_dc_ldapenum_pso.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --dc-list', outfile='netexec_dc_ldapenum_dc_list.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --find-delegation', outfile='netexec_dc_ldapenum_delegation.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --trusted-for-delegation', outfile='netexec_dc_ldapenum_unconstrained_delegation.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --groups "Backup Operators"', outfile='netexec_dc_ldapenum_backup_operators.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --groups "Domain Admins"', outfile='netexec_dc_ldapenum_domain_admins.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' --admin-count', outfile='netexec_dc_ldapenum_admin_count.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M get-desc-users', outfile='netexec_dc_ldapenum_get_desc_users.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M get-network -o ALL=true', outfile='netexec_dc_ldapenum_subnets.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M entra-id', outfile='netexec_dc_ldapenum_entra_id.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M obsolete', outfile='netexec_dc_ldapenum_obsolete.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M userPassword', outfile='netexec_dc_ldapenum_userPassword.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M unixUserPassword', outfile='netexec_dc_ldapenum_unixUserPassword.txt')
				await service.execute('nxc smb {address} -u ' + username + ' -H ' + nthash + ' -M adcs', outfile='netexec_dc_ldapenum_adcs.txt')
				await service.execute('nxc ldap {address} -u ' + username + ' -H ' + nthash + ' -M pre2k', outfile='netexec_dc_ldapenum_pre2k.txt')
		else:
			self.error('nxc requires username global option to be set.')
