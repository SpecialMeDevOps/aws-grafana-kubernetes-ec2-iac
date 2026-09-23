FROM nginx:1.27-alpine

WORKDIR /usr/share/nginx/html
COPY index.html .
COPY style.css .
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
