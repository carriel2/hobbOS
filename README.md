# 💽 hobbOS

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![XFCE](https://img.shields.io/badge/XFCE-2284F2?style=for-the-badge&logo=xfce&logoColor=white)
![Status](https://img.shields.io/badge/Status-Em_Desenvolvimento-brightgreen?style=for-the-badge)

O **hobbOS** é uma distribuição Linux customizada (Respin) baseada no poderoso **Arch Linux**. Nascido como um projeto de estudo profundo sobre arquitetura de sistemas operacionais, o objetivo do hobbOS é unir a base moderna, rolling-release e minimalista do Arch com uma experiência visual profundamente nostálgica, recriando a interface clássica do Windows XP.

## ✨ Características Principais

* **Base Sólida:** Construído do zero utilizando o `archiso` seguindo a filosofia *The Arch Way*.
* **Leve e Rápido:** Utiliza o ambiente gráfico **XFCE4**, garantindo baixo consumo de recursos e alta performance, ideal tanto para máquinas modernas quanto antigas.
* **Estética Retrô:** Temas, ícones e comportamentos de janela meticulosamente configurados para simular a era de ouro da computação (Estilo Windows XP).
* **Live CD / Rescue USB:** Pode ser inicializado diretamente de um pendrive sem necessidade de instalação, servindo como uma excelente ferramenta de resgate com estilo.

## 🛠️ Como construir (Build) a ISO

Este repositório contém os arquivos de configuração (profile) necessários para gerar a imagem `.iso`. Ele não contém binários pesados.

### Pré-requisitos
Para compilar o hobbOS, você precisará de uma máquina (ou VPS) rodando **Arch Linux** com o pacote `archiso` instalado.

```bash
# Atualize o sistema e instale o archiso e o git
sudo pacman -Syu archiso git
