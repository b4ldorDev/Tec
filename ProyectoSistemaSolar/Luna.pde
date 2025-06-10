class Luna {
  float distancia;    // Qué tan lejos está del planeta
  float angulo;       // Dónde está en su órbita (en radianes)
  float velocidad;    // Qué tan rápido gira alrededor
  float radio;        // El tamaño de la luna
  color colorBase;    // Color por si no hay textura
  PImage textura;     // La imagen de la superficie
  boolean usarTextura; // Si debemos usar textura o color
  
  // Constructor - lo que se ejecuta al crear una luna nueva
  Luna(float dist, float vel, float tam, color col, PImage tex, boolean texturasOK) {
    distancia = dist;
    angulo = random(TWO_PI); // Empezar en una posición aleatoria de la órbita
    velocidad = vel;
    radio = tam;
    colorBase = col;
    textura = tex;
    usarTextura = texturasOK && tex != null;
  }
  
  // Actualizar la posición de la luna
  void actualizar() {
    // Mover en la órbita según su velocidad (siempre, incluso en modo manual)
    angulo += velocidad;
  }
  
  // Dibujar la luna
  void mostrar() {
    pushMatrix();  // Guardar la posición actual
    
    // Dibujamos la órbita de la luna
    noFill();
    stroke(100, 30);  // Línea gris muy transparente
    ellipse(0, 0, distancia * 2, distancia * 2);  // La órbita circular
    
    // Movemos la luna a su posición en la órbita
    rotate(angulo);              // Giramos según el ángulo
    translate(distancia, 0);     // Y nos movemos a la distancia correcta
    
    // Dibujamos la luna
    if (usarTextura && textura != null) {
      // Con textura si la tenemos y está activada
      noStroke();
      PShape esfera = createShape(SPHERE, radio);
      esfera.setTexture(textura);
      shape(esfera);
    } else {
      // Sin textura, solo color
      noStroke();
      fill(colorBase);
      sphere(radio);
    }
    
    popMatrix();  // Volver a la posición original
  }
}
