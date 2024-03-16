docker build -t cfssl . && docker rm cfssl -f && docker run -p 3000:3000 --name cfssl --env-file .env --env-file .env.secrets --rm -dit cfssl 
# docker build -t cfssl .
