from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    wait_time = between(1, 2)

    @task
    def index(self):
        self.client.get('/-/nftforgood_uffc/-/ogy.nftforgood_uffc.0/-/ogy.nftforgood_uffc.0.ex')

    @task
    def image1(self):
        self.client.get('/-/impossible_pass/collection/-/ogy.mintpass.preview.png')
    @task
    def image2(self):
        self.client.get('/-/nftforgood_uffc/-/ogy.nftforgood_uffc.0/-/ogy.nftforgood_uffc.0.preview')

    @task
    def image3(self):
        self.client.get('/-/impossible_pass/collection/-/ogy.mintpass.preview.jpg')

    @task
    def video1(self):
        self.client.get('/-/impossible_pass/collection/-/ogy.mintpass.landscape.hd')

    @task
    def video2(self):
        self.client.get('/-/nftforgood_uffc/-/ogy.nftforgood_uffc.0/-/ogy.nftforgood_uffc.0.primary')

    @task
    def video3(self):
        self.client.get('/-/impossible_pass/collection/-/ogy.mintpass.portrait.hd')

    @task
    def video4(self):
        self.client.get('/-/laxi2-vqaaa-aaaaj-awc2a-cai/collection/-/ogy.simple.Impossible_Pass_HD_Landscape.mp4')
