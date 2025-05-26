// Juego de Snake en Processing usando POO

// Variables globales
Game game;
int filas = 40;
int columnas = 40;
int bs = 20; // Tamaño de los bloques

void setup() {
  size(800, 800);
  frameRate(10);
  game = new Game();
}

void draw() {
  game.update();
  game.display();
}

void keyPressed() {
  game.handleKeyPress();
}

// Clase principal del juego
class Game {
  Snake snake;
  ArrayList<Food> manzanas; // Ahora múltiples manzanas
  Obstacle obstaculo;
  boolean gameOver = false;
  int score = 0;
  int lastFoodTime = 0; // Tiempo de la última manzana agregada
  int currentSpeed = 10; // Velocidad inicial
  
  Game() {
    snake = new Snake();
    manzanas = new ArrayList<Food>();
    // Iniciar con 5 manzanas
    for (int i = 0; i < 5; i++) {
      addNewFood();
    }
    obstaculo = new Obstacle();
    lastFoodTime = millis();
  }
  
  void update() {
    if (gameOver) return;
    
    // Agregar nuevas manzanas cada minuto (60000 ms)
    if (millis() - lastFoodTime >= 60000) {
      for (int i = 0; i < 5; i++) {
        addNewFood();
      }
      lastFoodTime = millis();
    }
    
    // Ajustar velocidad cada 10 puntos
    int newSpeed = 10 + (score / 10) * 2;
    if (newSpeed != currentSpeed) {
      currentSpeed = newSpeed;
      frameRate(currentSpeed);
    }
    
    // Actualizar el movimiento del snake
    snake.move();
    
    // Detectar colisión con los bordes
    if (snake.posX.get(0) < 0 || snake.posX.get(0) >= columnas ||
        snake.posY.get(0) < 0 || snake.posY.get(0) >= filas) {
      gameOver = true;
      return;
    }
    
    // Detectar colisión con uno mismo
    for (int i = 1; i < snake.posX.size(); i++) {
      if (snake.posX.get(0) == snake.posX.get(i) && 
          snake.posY.get(0) == snake.posY.get(i)) {
        gameOver = true;
        return;
      }
    }
    
    // Detectar colisión con las manzanas
    for (int i = manzanas.size() - 1; i >= 0; i--) {
      Food manzana = manzanas.get(i);
      if (snake.posX.get(0) == manzana.x && snake.posY.get(0) == manzana.y) {
        snake.grow();
        manzanas.remove(i); // Remover la manzana comida
        score += 10;
        break; // Solo comer una manzana por frame
      }
    }
    
    // Si no come manzana, eliminamos la última posición para mantener el tamaño
    if (manzanas.size() > 0) {
      boolean ateFood = false;
      for (Food manzana : manzanas) {
        if (snake.posX.get(0) == manzana.x && snake.posY.get(0) == manzana.y) {
          ateFood = true;
          break;
        }
      }
      if (!ateFood) {
        snake.tail();
      }
    } else {
      snake.tail();
    }
    
    // Detectar colisión con el obstáculo
    if (snake.posX.get(0) == obstaculo.x && snake.posY.get(0) == obstaculo.y) {
      gameOver = true;
      return;
    }
  }
  
  void display() {
    background(255);
    
    // Dibujar la cuadrícula
    drawGrid();
    
    // Dibujar los elementos del juego
    for (Food manzana : manzanas) {
      manzana.display();
    }
    obstaculo.display();
    snake.display();
    
    // Mostrar puntuación y velocidad
    fill(0);
    textSize(20);
    text("Puntuación: " + score, 10, height - 40);
    text("Velocidad: " + currentSpeed + " FPS", 10, height - 15);
    text("Manzanas: " + manzanas.size(), 200, height - 15);
    
    // Mostrar mensaje de Game Over
    if (gameOver) {
      fill(255, 0, 0);
      textSize(32);
      textAlign(CENTER, CENTER);
      text("GAME OVER", width/2, height/2);
      textSize(24);
      text("Puntuación final: " + score, width/2, height/2 + 40);
      textSize(18);
      text("Presiona R para reiniciar", width/2, height/2 + 80);
      textAlign(LEFT, BASELINE);
    }
  }
  
  void drawGrid() {
    stroke(200);
    // Dibujar líneas horizontales
    for (int i = 0; i < filas; i++) {
      line(0, i * bs, width, i * bs);
    }
    
    // Dibujar líneas verticales
    for (int i = 0; i < columnas; i++) {
      line(i * bs, 0, i * bs, height);
    }
  }
  
  void handleKeyPress() {
    if (gameOver) {
      if (key == 'r' || key == 'R') {
        restart();
      }
      return;
    }
    
    snake.changeDirection(key);
  }
  
  void restart() {
    snake = new Snake();
    manzanas = new ArrayList<Food>();
    // Reiniciar con 5 manzanas
    for (int i = 0; i < 5; i++) {
      addNewFood();
    }
    obstaculo = new Obstacle();
    gameOver = false;
    score = 0;
    currentSpeed = 10;
    frameRate(currentSpeed);
    lastFoodTime = millis();
  }
  
  void addNewFood() {
    Food newFood = new Food();
    // Asegurarse de que no aparezca donde está el snake o el obstáculo
    while (snake.isOnPosition(newFood.x, newFood.y) || 
           (newFood.x == obstaculo.x && newFood.y == obstaculo.y) ||
           isFoodOnPosition(newFood.x, newFood.y)) {
      newFood.reposition();
    }
    manzanas.add(newFood);
  }
  
  boolean isFoodOnPosition(int x, int y) {
    for (Food manzana : manzanas) {
      if (manzana.x == x && manzana.y == y) {
        return true;
      }
    }
    return false;
  }
}

// Clase de la serpiente
class Snake {
  ArrayList<Integer> posX = new ArrayList<Integer>();
  ArrayList<Integer> posY = new ArrayList<Integer>();
  int direccion = 3; // 0: arriba, 1: abajo, 2: izquierda, 3: derecha
  int[] dx = {0, 0, -1, 1};
  int[] dy = {-1, 1, 0, 0};
  
  Snake() {
    // Iniciar con una serpiente de un solo segmento
    posX.add(10);
    posY.add(10);
  }
  
  void move() {
    // Añadir nueva posición de la cabeza
    posX.add(0, posX.get(0) + dx[direccion]);
    posY.add(0, posY.get(0) + dy[direccion]);
  }
  
  void tail() {
    // Eliminar la cola cuando no crece
    posX.remove(posX.size() - 1);
    posY.remove(posY.size() - 1);
  }
  
  void grow() {
    // NO removemos la cola cuando la serpiente crece
    // La nueva cabeza ya fue agregada en move(), 
    // así que simplemente no llamamos tail() para mantener el tamaño aumentado
    // Esta función se ejecuta cuando come una manzana
  }
  
  void display() {
    fill(0, 0, 255);
    // Dibujar la cabeza con un color diferente
    rect(posX.get(0) * bs, posY.get(0) * bs, bs, bs);
    
    // Dibujar el cuerpo
    fill(0, 0, 200);
    for (int i = 1; i < posX.size(); i++) {
      rect(posX.get(i) * bs, posY.get(i) * bs, bs, bs);
    }
  }
  
  void changeDirection(char key) {
    // Cambiar dirección, prevenir que vaya en dirección opuesta
    if (key == 'w' && direccion != 1) direccion = 0;
    if (key == 's' && direccion != 0) direccion = 1;
    if (key == 'a' && direccion != 3) direccion = 2;
    if (key == 'd' && direccion != 2) direccion = 3;
    
    // Soporte para flechas del teclado
    if (keyCode == UP && direccion != 1) direccion = 0;
    if (keyCode == DOWN && direccion != 0) direccion = 1;
    if (keyCode == LEFT && direccion != 3) direccion = 2;
    if (keyCode == RIGHT && direccion != 2) direccion = 3;
  }
  
  boolean isOnPosition(int x, int y) {
    for (int i = 0; i < posX.size(); i++) {
      if (posX.get(i) == x && posY.get(i) == y) {
        return true;
      }
    }
    return false;
  }
}

class Food {
  int x, y;
  
  Food() {
    reposition();
  }
  
  void reposition() {
    x = (int) random(0, columnas);
    y = (int) random(0, filas);
  }
  
  void display() {
    fill(255, 0, 0);
    rect(x * bs, y * bs, bs, bs);
  }
}

// Clase para el obstáculo
class Obstacle {
  int x, y;
  
  Obstacle() {
    reposition();
  }
  
  void reposition() {
    x = (int) random(0, columnas);
    y = (int) random(0, filas);
  }
  
  void display() {
    fill(0, 255, 0);
    rect(x * bs, y * bs, bs, bs);
  }
}
