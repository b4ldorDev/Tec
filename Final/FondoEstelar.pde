class FondoEstelar {
  int numEstrellas;
  PVector[] posEstrellas;
  float[] brilloEstrellas;
  float[] velParpadeo;
  float[] tamañoEstrellas;
  
  FondoEstelar(int numEstrellitas) {
    numEstrellas = numEstrellitas;
    
    posEstrellas = new PVector[numEstrellas];
    brilloEstrellas = new float[numEstrellas];
    velParpadeo = new float[numEstrellas];
    tamañoEstrellas = new float[numEstrellas];
    
    for (int i = 0; i < numEstrellas; i++) {
      float theta = random(TWO_PI);
      float phi = random(PI);
      float radio = 2000;
      
      float x = radio * sin(phi) * cos(theta);
      float y = radio * sin(phi) * sin(theta);
      float z = radio * cos(phi);
      
      posEstrellas[i] = new PVector(x, y, z);
      brilloEstrellas[i] = random(150, 255);
      velParpadeo[i] = random(0.02, 0.1);
      tamañoEstrellas[i] = random(1, 3);
    }
  }
  
  void mostrar() {
    pushMatrix();
    
    //  gradiente
    pushMatrix();
    resetMatrix();
    hint(DISABLE_DEPTH_TEST);
    
    for (int i = 0; i <= height; i++) {
      float inter = map(i, 0, height, 0, 1);
      color c = lerpColor(color(0, 0, 10), color(5, 0, 20), inter);
      stroke(c);
      line(0, i, width, i);
    }
    
    hint(ENABLE_DEPTH_TEST);
    popMatrix();
    
    // poner estrellas
    for (int i = 0; i < numEstrellas; i++) {
      pushMatrix();
      translate(posEstrellas[i].x, posEstrellas[i].y, posEstrellas[i].z);
      
      // orientar hacia la camara
      rotateY(atan2(-posEstrellas[i].z, -posEstrellas[i].x));
      rotateX(atan2(-posEstrellas[i].y, sqrt(posEstrellas[i].x * posEstrellas[i].x + posEstrellas[i].z * posEstrellas[i].z)));
      
      // efecto de parpadeo
      float brilloActual = brilloEstrellas[i] * (0.7 + 0.3 * sin(frameCount * velParpadeo[i]));
      fill(brilloActual);
      noStroke();
      
      // dibujar estrella
      ellipse(0, 0, tamañoEstrellas[i], tamañoEstrellas[i]);
      
      // rayos de luz para estrellas grandes
      if (tamañoEstrellas[i] > 2) {
        stroke(brilloActual, 150);
        float largoRayo = tamañoEstrellas[i] * 2;
        line(-largoRayo, 0, largoRayo, 0);
        line(0, -largoRayo, 0, largoRayo);
      }
      
      popMatrix();
    }
    
    popMatrix();
  }
}
