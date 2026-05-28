FROM node:20-alpine

# Crear directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias primero (cache layer)
COPY package.json ./

# Instalar dependencias de produccion
RUN npm install --omit=dev

# Copiar el codigo de la aplicacion
COPY server.js ./

# Exponer puerto
EXPOSE 3000

# Comando de inicio
CMD ["node", "server.js"]
