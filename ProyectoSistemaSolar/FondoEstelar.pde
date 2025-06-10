class FondoEstelar {
  // Variables para las estrellas
  int numEstrellas;            // Cuántas estrellas queremos
  PVector[] posEstrellas;      // Posición 3D de cada estrella
  float[] brilloEstrellas;     // Qué tan brillantes son
  float[] velParpadeo;         // Qué tan rápido parpadean
  float[] tamañoEstrellas;     // Qué tan grandes son
  
  // Constructor - se ejecuta al crear un nuevo fondo
  FondoEstelar(int numEstrellitas) {
    numEstrellas = numEstrellitas;
    
    // Crear los arrays para guardar los datos de cada estrella
    posEstrellas = new PVector[numEstrellas];
    brilloEstrellas = new float[numEstrellas];
    velParpadeo = new float[numEstrellas];
    tamañoEstrellas = new float[numEstrellas];
    
    // Inicializar cada estrella con valores aleatorios
    for (int i = 0; i < numEstrellas; i++) {
      // Creamos estrellas en una esfera grande (como si fuera el cielo)
      float theta = random(TWO_PI);     // Ángulo horizontal (0 a 360 grados)
      float phi = random(PI);           // Ángulo vertical (0 a 180 grados)
      float radio = 2000;               // Super lejos para que parezcan estrellas
      
      // Convertir coordenadas esféricas a cartesianas (x,y,z)
      float x = radio * sin(phi) * cos(theta);
      float y = radio * sin(phi) * sin(theta);
      float z = radio * cos(phi);
      
      // Guardar todos los valores
      posEstrellas[i] = new PVector(x, y, z);
      brilloEstrellas[i] = random(150, 255);      // Brillo entre medio y máximo
      velParpadeo[i] = random(0.02, 0.1);         // Velocidad de parpadeo variada
      tamañoEstrellas[i] = random(1, 3);          // Tamaños entre 1 y 3 píxeles
    }
  }
  
  // Método para mostrar todo el fondo estelar
  void mostrar() {
    pushMatrix();  // Guardar posición
    
    // Primero dibujamos un gradiente chido de fondo
    pushMatrix();
    resetMatrix();  // Para que el gradiente ocupe toda la pantalla
    hint(DISABLE_DEPTH_TEST);  // Desactivamos la profundidad temporalmente
    
    // Hacemos líneas horizontales con degradado de azul oscuro
    for (int i = 0; i <= height; i++) {
      float inter = map(i, 0, height, 0, 1);  // Valor entre 0 y 1 según la altura
      color c = lerpColor(color(0, 0, 10), color(5, 0, 20), inter);  // Mezclamos colores azul oscuro
      stroke(c);  // Aplicamos el color
      line(0, i, width, i);  // Dibujamos una línea horizontal
    }
    
    hint(ENABLE_DEPTH_TEST);  // Volvemos a activar la profundidad
    popMatrix();
    
    // Ahora dibujamos todas las estrellas
    for (int i = 0; i < numEstrellas; i++) {
      pushMatrix();
      // Nos movemos a la posición de la estrella
      translate(posEstrellas[i].x, posEstrellas[i].y, posEstrellas[i].z);
      
      // Hacemos que la estrella siempre mire hacia la cámara
      rotateY(atan2(-posEstrellas[i].z, -posEstrellas[i].x));
      rotateX(atan2(-posEstrellas[i].y, sqrt(posEstrellas[i].x * posEstrellas[i].x + posEstrellas[i].z * posEstrellas[i].z)));
      
      // Calculamos el brillo actual con efecto de parpadeo usando seno
      float brilloActual = brilloEstrellas[i] * (0.7 + 0.3 * sin(frameCount * velParpadeo[i]));
      fill(brilloActual);
      noStroke();
      
      // Dibujamos la estrella como un círculo pequeño
      ellipse(0, 0, tamañoEstrellas[i], tamañoEstrellas[i]);
      
      // Para estrellas más grandes, le ponemos rayitos de luz
      if (tamañoEstrellas[i] > 2) {
        stroke(brilloActual, 150);
        float largoRayo = tamañoEstrellas[i] * 2;
        // Rayos horizontales y verticales
        line(-largoRayo, 0, largoRayo, 0);
        line(0, -largoRayo, 0, largoRayo);
      }
      
      popMatrix();
    }
    
    popMatrix();
  }
}
