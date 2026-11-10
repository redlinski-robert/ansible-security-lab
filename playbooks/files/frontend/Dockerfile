FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# Instalujemy zaleznosci
RUN npm install

# Kopiujemy reszte kodu
COPY . .

# Kluczowy krok: Nadanie uprawnien do wykonywania skryptow binarnych
RUN chmod -R +x node_modules/.bin

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]