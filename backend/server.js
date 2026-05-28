const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuracion del pool de conexiones a PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'taskdb',
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD || 'secret123',
});

app.use(cors({
  origin: '*'
}));
app.use(express.json());

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/api/setup', async (req, res) => {
  try {
    await pool.query(`CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT DEFAULT '',
      completed BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )`);
    await pool.query(`INSERT INTO tasks (title, description, completed) VALUES
      ('Instalar Ubuntu Server', 'Crear VM en VirtualBox', true),
      ('Instalar Docker', 'Seguir documentacion oficial', true),
      ('Desplegar en cloud', 'Usar Render como proveedor', false)
    `);
    res.json({ status: 'ok', message: 'Tabla creada e iniciada' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ status: 'error', db: 'disconnected', error: err.message });
  }
});

// ── GET /api/tasks — listar todas ─────────────────────────────────────────────
app.get('/api/tasks', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM tasks ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error listando tareas:', err.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// ── POST /api/tasks — crear tarea ─────────────────────────────────────────────
app.post('/api/tasks', async (req, res) => {
  const { title, description } = req.body;
  if (!title || title.trim() === '') {
    return res.status(400).json({ error: 'El titulo es obligatorio' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING *',
      [title.trim(), (description || '').trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creando tarea:', err.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// ── PATCH /api/tasks/:id — cambiar estado ─────────────────────────────────────
app.patch('/api/tasks/:id', async (req, res) => {
  const { id } = req.params;
  const { completed } = req.body;
  try {
    const result = await pool.query(
      'UPDATE tasks SET completed=$1, updated_at=NOW() WHERE id=$2 RETURNING *',
      [completed, id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Tarea no encontrada' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error actualizando tarea:', err.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// ── DELETE /api/tasks/:id — eliminar tarea ────────────────────────────────────
app.delete('/api/tasks/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM tasks WHERE id=$1', [id]);
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Tarea no encontrada' });
    }
    res.json({ message: 'Tarea eliminada' });
  } catch (err) {
    console.error('Error eliminando tarea:', err.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[Backend] Servidor corriendo en puerto ${PORT}`);
});
