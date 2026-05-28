FROM nginx:alpine

# Copiar la aplicacion web
COPY index.html /usr/share/nginx/html/index.html

# Copiar configuracion de nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
