<p align="center">
  <h3 align="center">Trojan Autoconf</h3>
  <p align="center">Boilerplate configuration for trojan server (trojan-gfw).</p>

  <p align="center">
    <a href="https://github.com/GouveaHeitor/nipe/blob/master/LICENSE.md">
      <img src="https://img.shields.io/badge/license-MIT-blue.svg">
    </a>
  </p>
</p>

---

<p align="center">
    <img src="https://user-images.githubusercontent.com/10201704/66357447-c6f98000-e97b-11e9-9d28-ddc32205cc62.jpg" alt="how it works">
</p>


### Requirements:
```
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

pip3 install -U docker-compose
```

useful documentations:
* [config trojan](https://trojan-gfw.github.io/trojan/config)
* [install docker](https://docs.docker.com/install/)
* [install docker-compose](https://docs.docker.com/compose/install/)

### Installation

```
# Install docker and docker-compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

pip3 install -U docker-compose

git clone https://github.com/itshaadi/trojan-autoconf.git
cd trojan-autoconf
chmod +x configure.sh
```

### Usage

```
Usage: 
 	 <domain> <optional:email> 
 	 eg: ./configure.sh mywebsite.com hello@gmail.com
```

### Defaults:
* password: `trojan-autoconf`