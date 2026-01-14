from autorecon.plugins import ServiceScan

class Nuclei(ServiceScan):

    def __init__(self):
        super().__init__()
        self.name = 'Nuclei'
        self.tags = ['default', 'safe', 'http']

    def configure(self):
        self.match_service_name('^http')
        self.match_service_name('^nacn_http$', negative_match=True)

    async def run(self, service):
        await service.execute('nuclei -ut && nuclei -t ~/nuclei-templates/ -severity medium,high,critical -rate-limit 150 -concurrency 50 -disable-clustering -u {http_scheme}://{addressv6}:{port}/ -output {scandir}/{protocol}_{port}_{http_scheme}_nuclei.txt')
