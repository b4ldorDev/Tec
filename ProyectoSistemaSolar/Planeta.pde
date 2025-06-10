class Planeta {
  float distancia;    // Qué tan lejos está del centro
  float angulo;       // Dónde está en su órbita (en radianes)
  float velocidad;    // Qué tan rápido gira alrededor
  float radio;        // El tamaño del planeta
  color colorBase;    // Color por si no hay textura
  PImage textura;     // La imagen de la superficie
  boolean usarTextura; // Si debemos usar textura o color
  
  ArrayList<Planeta> planetas; // Planetas que orbitan a este
  ArrayList<Luna> lunas;       // Lunas que orbitan a este
  
  // Constructor - lo que se ejecuta al crear un planeta nuevo
  Planeta(float dist, float vel, float tam, color col, PImage tex, boolean texturasOK) {
    distancia = dist;
    angulo = random(TWO_PI); // Empezar en una posición aleatoria de la órbita
    velocidad = vel;
    radio = tam;
    colorBase = col;
    textura = tex;
    usarTextura = texturasOK && tex != null;
    
    // Listas vacías para agregar planetas y lunas después
    planetas = new ArrayList<Planeta>();
    lunas = new ArrayList<Luna>();
  }
  
  // Método para agregar un planeta que orbite a este
  void agregarPlaneta(Planeta p) {
    planetas.add(p);  // Lo metemos a la lista
  }
  
  // Método para agregar una luna que orbite a este
  void agregarLuna(Luna l) {
    lunas.add(l);  // La metemos a la lista
  }
  
  // Actualizar la posición de este planeta y todo lo que orbita
  void actualizar() {
    // Mover en la órbita según su velocidad (solo si no estamos en modo manual)
    if (!modoManual || (modoManual && planetaSeleccionado != 0 && this == sol)) {
      angulo += velocidad;
    }
    
    // Actualizar todos los planetas que orbitan
    for (Planeta p : planetas) {
      p.actualizar();
    }
    
    // Actualizar todas las lunas que orbitan
    for (Luna l : lunas) {
      l.actualizar();
    }
  }
  
  // Dibujar el planeta y todo lo que orbita
  void mostrar() {
    pushMatrix();  // Guardar la posición actual
    
    // Si es el sol (distancia == 0)
    if (distancia == 0) {
      // Dibujar el sol
      if (usarTextura && textura != null) {
        // Con textura si la tenemos
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
      
      // Destacar el planeta seleccionado en modo manual
      if (modoManual && planetaSeleccionado == 0) {
        noFill();
        stroke(255); // Cambiado a blanco
        strokeWeight(2);
        sphere(radio + 5);
      }
      
      // Mostrar planetas que orbitan al sol
      for (int i = 0; i < planetas.size(); i++) {
        // Resaltar el planeta seleccionado
        if (modoManual && planetaSeleccionado == i + 1) {
          stroke(255); // Cambiado a blanco
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
      // Si no es el sol, dibujamos su órbita
      noFill();
      stroke(100, 50);  // Línea gris transparente
      ellipse(0, 0, distancia * 2, distancia * 2);  // La órbita circular
      
      // Movemos el planeta a su posición en la órbita
      rotate(angulo);              // Giramos según el ángulo
      translate(distancia, 0);     // Y nos movemos a la distancia correcta
      
      // Dibujamos el planeta
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
      
      // Dibujamos las lunas que orbitan a este planeta
      for (Luna l : lunas) {
        l.mostrar();
      }
    }
    
    popMatrix();  // Volver a la posición original
  }
}
