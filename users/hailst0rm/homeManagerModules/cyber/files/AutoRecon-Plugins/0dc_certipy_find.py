from autorecon.plugins import ServiceScan
from shutil import which

class Certipy_Find(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = 'Certipy Find'
		self.tags = ['safe', 'ldap', 'auth', 'active-directory']

	def configure(self):
		self.match_service_name(['^ldap', '^ldaps', '^kerberos', '^msrpc', '^ms-ds'])
		self.match_port('tcp', [88, 389, 636, 3268, 3269])
		self.run_once(True)

	def check(self):
		if which('certipy') is None:
			self.error('The program certipy could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		ldap_fallback = ' -ldap-scheme ldap -ldap-port 389 -no-ldap-channel-binding -no-ldap-signing'
		if self.get_global('domain') and self.get_global('ticket'):
			domain = self.get_global('domain')
			await service.execute('cd {scandir} && certipy find -k -dc-ip {address} -enabled -hide-admins -text -output certipy_ldaps', outfile='certipy_find_ldaps.txt')
			await service.execute('cd {scandir} && certipy find -k -dc-ip {address} -enabled -hide-admins -text -output certipy_ldap' + ldap_fallback, outfile='certipy_find_ldap.txt')
		elif self.get_global('username') and self.get_global('domain'):
			username = self.get_global('username')
			domain = self.get_global('domain')
			if self.get_global('password'):
				password = self.get_global('password')
				await service.execute('cd {scandir} && certipy find -u "' + username + '@' + domain + '" -p ' + password + ' -dc-ip {address} -enabled -hide-admins -text -output certipy_ldaps', outfile='certipy_find_ldaps.txt')
				await service.execute('cd {scandir} && certipy find -u "' + username + '@' + domain + '" -p ' + password + ' -dc-ip {address} -enabled -hide-admins -text -output certipy_ldap' + ldap_fallback, outfile='certipy_find_ldap.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				await service.execute('cd {scandir} && certipy find -u "' + username + '@' + domain + '" -hashes ' + nthash + ' -dc-ip {address} -enabled -hide-admins -text -output certipy_ldaps', outfile='certipy_find_ldaps.txt')
				await service.execute('cd {scandir} && certipy find -u "' + username + '@' + domain + '" -hashes ' + nthash + ' -dc-ip {address} -enabled -hide-admins -text -output certipy_ldap' + ldap_fallback, outfile='certipy_find_ldap.txt')
			if self.get_global('aeskey'):
				aeskey = self.get_global('aeskey')
				await service.execute('cd {scandir} && certipy find -u "' + username + '@' + domain + '" -aes ' + aeskey + ' -dc-ip {address} -enabled -hide-admins -text -output certipy_ldaps', outfile='certipy_find_ldaps.txt')
				await service.execute('cd {scandir} && certipy find -u "' + username + '@' + domain + '" -aes ' + aeskey + ' -dc-ip {address} -enabled -hide-admins -text -output certipy_ldap' + ldap_fallback, outfile='certipy_find_ldap.txt')
		else:
			self.error('certipy requires username and domain global options to be set.')
