sudo apt update

sudo apt install -y python3.12-venv

python3 -m venv .venv

source .venv/bin/activate

python -m pip install boto3
