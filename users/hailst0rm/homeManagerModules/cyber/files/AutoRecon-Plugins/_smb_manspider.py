from autorecon.plugins import ServiceScan

class Manspider(ServiceScan):

	def __init__(self):
		super().__init__()
		self.name = "Manspider"
		self.tags = ['default', 'safe', 'smb', 'active-directory', 'auth']

	def configure(self):
		self.match_service_name(['^smb', '^microsoft-ds', '^netbios'])
		self.match_port('tcp', 445)
		self.run_once(True)

	def check(self):
		if which('manspider') is None:
			self.error('The program manspider could not be found. Make sure it is installed.')
			return False

	async def run(self, service):
		if self.get_global('username'):
			username = self.get_global('username')
			if self.get_global('password'):
				password = self.get_global('password')
				# Search for credential-related filenames
				await service.execute('manspider {address} -u ' + username + ' -p ' + password + ' -f passw user admin login cred secret -n -q', outfile='manspider_filenames_creds.txt')
				# Search for sensitive file extensions
				await service.execute('manspider {address} -u ' + username + ' -p ' + password + ' -e bat vbs ps1 pem key pfx kdbx 1pif opvault psafe3 ppk -n -q', outfile='manspider_extensions_sensitive.txt')
				# Search spreadsheets and docs for password references
				await service.execute('manspider {address} -u ' + username + ' -p ' + password + ' -c passw -e xlsx csv docx pdf txt -q', outfile='manspider_content_passwords.txt')
				# Search for SSH keys by content
				await service.execute("manspider {address} -u " + username + " -p " + password + " -e '' -c 'BEGIN .{{1,10}} PRIVATE KEY' -q", outfile='manspider_content_sshkeys.txt')
			if self.get_global('nthash'):
				nthash = self.get_global('nthash')
				# Search for credential-related filenames
				await service.execute('manspider {address} -u ' + username + ' -H ' + nthash + ' -f passw user admin login cred secret -n -q', outfile='manspider_filenames_creds.txt')
				# Search for sensitive file extensions
				await service.execute('manspider {address} -u ' + username + ' -H ' + nthash + ' -e bat vbs ps1 pem key pfx kdbx 1pif opvault psafe3 ppk -n -q', outfile='manspider_extensions_sensitive.txt')
				# Search spreadsheets and docs for password references
				await service.execute('manspider {address} -u ' + username + ' -H ' + nthash + ' -c passw -e xlsx csv docx pdf txt -q', outfile='manspider_content_passwords.txt')
				# Search for SSH keys by content
				await service.execute("manspider {address} -u " + username + " -H " + nthash + " -e '' -c 'BEGIN .{{1,10}} PRIVATE KEY' -q", outfile='manspider_content_sshkeys.txt')
