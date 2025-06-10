class Planeta {
  float distancia;
  float angulo;
  float velocidad;
  float radio;
  color colorBase;
  PImage textura;
  boolean usarTextura;
  
  ArrayList<Planeta> planetas;
  ArrayList<Luna> lunas;
  
  Planeta(float dist, float vel, float tam, color col, PImage tex, boolean texturasOK) {
    distancia = dist;
    angulo = random(TWO_PI);
    velocidad = vel;
    radio = tam;
    colorBase = col;
    textura = tex;
    usarTextura = texturasOK && tex != null;
    
    planetas = new ArrayList<Planeta>();
    lunas = new ArrayList<Luna>();
  }
  
  void agregarPlaneta(Planeta p) {
    planetas.add(p);
  }
  
  void agregarLuna(Luna l) {
    lunas.add(l);
  }
  
  void actualizar() {
    if (!modoManual || (modoManual && planetaSeleccionado != 0 && this == sol)) {
      angulo += velocidad;
    }
    
    for (Planeta p : planetas) {
      p.actualizar();
    }
    
    for (Luna l : lunas) {
      l.actualizar();
    }
  }
  
  void mostrar() {
    pushMatrix();
    
    if (distancia == 0) {
      // dibujar sol
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
      
      // destacar si esta seleccionado
      if (modoManual && planetaSeleccionado == 0) {
        noFill();
        stroke(255);
        strokeWeight(2);
        sphere(radio + 5);
      }
      
      // mostrar planetas orbitando
      for (int i = 0; i < planetas.size(); i++) {
        if (modoManual && planetaSeleccionado == i + 1) {
          stroke(255);
          strokeWeight(2);
          noFill();
          pushMatrix();
          rotate(planetas.get(i).angulo);
          translate(planetas.get(i).distancia, 0);
          sphere(planetas.get(i).radio + 5);
          popMatrix();
        }
        
        planetas.get(i).mostrar();
      }
    } else {
      // dibujar orbita
      noFill();
      stroke(100, 50);
      ellipse(0, 0, distancia * 2, distancia * 2);
      
      // posicionar planeta
      rotate(angulo);
      translate(distancia, 0);
      
      // dibujar planeta
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
      
      // mostrar lunas
      for (Luna l : lunas) {
        l.mostrar();
      }
    }
    
    popMatrix();
  }
}
