class Luna {
  float distancia;
  float angulo;
  float velocidad;
  float radio;
  color colorBase;
  PImage textura;
  boolean usarTextura;
  
  Luna(float dist, float vel, float tam, color col, PImage tex, boolean texturasOK) {
    distancia = dist;
    angulo = random(TWO_PI);
    velocidad = vel;
    radio = tam;
    colorBase = col;
    textura = tex;
    usarTextura = texturasOK && tex != null;
  }
  
  void actualizar() {
    angulo += velocidad;
  }
  
  void mostrar() {
    pushMatrix();
    
    // orbita
    noFill();
    stroke(100, 30);
    ellipse(0, 0, distancia * 2, distancia * 2);
    
    // posicionar luna
    rotate(angulo);
    translate(distancia, 0);
    
    // poner luna
    if (usarTextura && textura != null) {
      noStroke();
      PShape esfera = createShape(SPHERE, radio);
      esfera.setTexture(textura);
      shape(esfera);
    } else {
      noStroke();
      fill(colorBase);
      sphere(radio);
    }
    
    popMatrix();
  }
}
