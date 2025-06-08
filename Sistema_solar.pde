import peasy.*;

PeasyCam cam; 
Planet sol;   

void setup() {
  size(800, 600, P3D); 
  
  cam = new PeasyCam(this, 400);  // esto es para la camara, 400 es que tan lejos empieza
  crearSistemaSolar();
}

// aqui se ejecuta todo el tiempo, como un loop infinito
void draw() {
  background(0);   
  // actualizar y mostrar todo
  sol.update();  // mover todos los planetas
  sol.show();    // dibujar el sol y planetas
}

void crearSistemaSolar() {
  // crear el sol: distancia=0, velocidad=0, tamaño=30, amarillo, sin lunas
  sol = new Planet(0, 0, 30, color(255, 200, 0), null);
  
  // array con 4 planetas
  Planet[] planetas = new Planet[4];
  
  // mercurio: cerquita, rapido, chiquito, gris
  planetas[0] = new Planet(60, 0.05, 3, color(150, 150, 150), null);
  
  // venus: mas lejos, mas lento, naranja
  planetas[1] = new Planet(90, 0.03, 5, color(255, 150, 50), null);
  
  // tierra: con su luna
  Planet[] lunas = new Planet[1];  // array para la luna
  lunas[0] = new Planet(20, 0.1, 2, color(200, 200, 200), null);  // luna chiquita y rapida
  planetas[2] = new Planet(120, 0.02, 6, color(0, 100, 200), lunas);  // tierra azul con luna
  
  // marte: lejitos, lento, rojo
  planetas[3] = new Planet(160, 0.015, 4, color(200, 50, 50), null);
  
  // meter todos los planetas al sol
  sol.planets = planetas;
}

// clase para cada planeta
class Planet {
  // propiedades de cada planeta
  float distance;     // que tan lejos esta del centro
  float angle;        // donde esta en su orbita
  float angleSpeed;   // que tan rapido gira
  float radius;       // tamaño
  color col;          // color
  Planet[] planets;   // otros planetas que lo orbitan (lunas)
  
  // constructor - cuando creamos un planeta nuevo
  Planet(float d, float speed, float r, color c, Planet[] p) {
    distance = d;      
    angle = 0;         // empezar en 0
    angleSpeed = speed; 
    radius = r;        
    col = c;           
    planets = p;       
  }
  
  // actualizar posicion cada frame
  void update() {
    angle += angleSpeed;  // mover en la orbita
    
    // si tiene lunas o planetas
    if (planets != null) {
      // actualizar cada uno
      for (int i = 0; i < planets.length; i++) {
        planets[i].update();  
      }
    }
  }
  
  // dibujar el planeta y sus lunas
  void show() {
    pushMatrix();  // guardar posicion actual
    
    // dibujar la orbita (el circulo)
    if (distance > 5) {  // si no es el sol
      stroke(100, 50);     // gris transparente
      noFill();            // sin relleno
      rotateX(PI/2);       // rotar para que quede horizontal
      ellipse(0, 0, distance * 2, distance * 2);  // circulo de orbita
      rotateX(-PI/2);      // volver a como estaba
    }
    
    // dibujar el planeta
    fill(col);           // color del planeta
    stroke(255, 100);    // borde blanco transparente
    
    rotate(angle);       // rotar segun donde esta en la orbita
    translate(distance, 0);  // mover a la distancia correcta
    
    sphere(radius);      // dibujar la pelotita
    
    // dibujar lunas si tiene
    if (planets != null) {
      for (int i = 0; i < planets.length; i++) {
        planets[i].show();  // cada luna se dibuja sola
      }
    }
    
    popMatrix();  // volver a la posicion original
  }
}

// cuando presionamos una tecla
void keyPressed() {
  if (key == 'r') {
    cam.reset();  // resetear camara
  }
}
