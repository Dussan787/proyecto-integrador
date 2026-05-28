-- Script de inicializacion de la base de datos
-- Se ejecuta automaticamente al crear el contenedor

CREATE TABLE IF NOT EXISTS tasks (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    completed   BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);

-- Datos de ejemplo para demostrar la aplicacion
INSERT INTO tasks (title, description, completed) VALUES
  ('Instalar Ubuntu Server en VirtualBox', 'Crear VM con 2GB RAM y 20GB disco', true),
  ('Configurar red en modo Bridge', 'Asignar IP estatica y verificar conectividad', true),
  ('Instalar Docker y Docker Compose', 'Seguir documentacion oficial de Docker', false),
  ('Crear script de automatizacion Bash', 'Script que valide servicios y genere logs', false),
  ('Desplegar aplicacion en cloud', 'Usar Oracle Cloud o Railway como alternativa', false);
