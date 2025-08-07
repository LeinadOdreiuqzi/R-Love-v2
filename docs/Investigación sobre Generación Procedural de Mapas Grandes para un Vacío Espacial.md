# Investigación sobre Generación Procedural de Mapas Grandes para un Vacío Espacial

## Introducción

La generación procedural de contenido (PCG) es una técnica poderosa para crear mundos de juego grandes y variados sin la necesidad de diseñar cada elemento a mano. En el contexto de un roguelike espacial, donde el mapa representa un "vacío espacial", el objetivo es generar un entorno que se sienta vasto, interesante y explorable, pero sin la densidad de un calabozo tradicional. Esto implica la creación de un espacio mayormente vacío salpicado de puntos de interés, como asteroides, nebulosas, estaciones espaciales abandonadas, etc.

Para un mapa de gran tamaño, la eficiencia es clave. No es factible generar y almacenar todo el mapa en memoria a la vez. Por lo tanto, se requieren algoritmos que puedan generar el contenido de manera eficiente y, preferiblemente, en "chunks" o fragmentos a medida que el jugador explora.

## Algoritmos y Técnicas para la Generación de Mapas Espaciales

### 1. Ruido de Perlin (Perlin Noise)

El ruido de Perlin es un algoritmo de generación de ruido pseudoaleatorio que produce texturas de apariencia natural. Es ideal para crear mapas de terreno, nubes, y otros fenómenos orgánicos. En un contexto espacial, el ruido de Perlin se puede utilizar para:

- **Generar campos de asteroides**: Se puede usar un mapa de ruido para determinar la densidad de asteroides en diferentes regiones del espacio. Las áreas con valores de ruido por encima de un cierto umbral podrían contener asteroides.
- **Crear nebulosas**: Múltiples capas de ruido de Perlin con diferentes frecuencias y amplitudes pueden combinarse para crear nebulosas de gas de aspecto realista.
- **Distribuir puntos de interés**: El ruido de Perlin puede usarse para crear una distribución más natural de puntos de interés, evitando patrones de cuadrícula predecibles.

**Ventajas**:
- Produce resultados de apariencia natural y orgánica.
- Es determinista: la misma semilla siempre producirá el mismo resultado, lo cual es ideal para la generación procedural basada en semillas.
- Es eficiente de calcular para puntos individuales, lo que permite la generación de chunks sobre la marcha.

**Desventajas**:
- Puede ser predecible si no se combina con otras técnicas.
- Requiere ajuste de parámetros (frecuencia, octavas, persistencia) para obtener los resultados deseados.

### 2. Diagramas de Voronoi

Los diagramas de Voronoi dividen un plano en regiones basadas en la proximidad a un conjunto de puntos. Cada región contiene todos los puntos que están más cerca de su punto semilla que de cualquier otro. En un juego espacial, los diagramas de Voronoi pueden ser útiles para:

- **Definir sistemas estelares o sectores**: Cada punto semilla puede representar una estrella o un punto de interés principal, y la región de Voronoi asociada puede ser el "territorio" de ese sistema.
- **Crear fronteras naturales**: Las líneas que dividen las regiones de Voronoi pueden usarse como fronteras entre diferentes tipos de espacio (por ejemplo, espacio profundo, campo de asteroides, nebulosa).
- **Generar rutas comerciales o de navegación**: Se pueden crear grafos a partir de los diagramas de Voronoi para generar rutas de navegación entre sistemas.

**Ventajas**:
- Crea estructuras celulares de apariencia natural.
- Es útil para dividir el espacio en regiones distintas.

**Desventajas**:
- Puede ser computacionalmente más costoso que el ruido de Perlin, especialmente para un gran número de puntos.

### 3. Autómatas Celulares

Los autómatas celulares son sistemas discretos que consisten en una cuadrícula de celdas, cada una de las cuales puede estar en uno de varios estados. El estado de cada celda evoluciona en pasos de tiempo discretos según un conjunto de reglas que dependen del estado de las celdas vecinas. El "Juego de la Vida" de Conway es un ejemplo famoso.

En la generación de mapas, los autómatas celulares se pueden usar para:

- **Generar cuevas o túneles en asteroides**: Se puede inicializar una cuadrícula con ruido aleatorio y luego aplicar reglas de autómata celular para "suavizar" el ruido y crear estructuras de cuevas.
- **Simular la propagación de fenómenos espaciales**: Se pueden usar para simular la expansión de una nebulosa o la formación de un campo de asteroides.

**Ventajas**:
- Puede generar estructuras complejas y de apariencia orgánica a partir de reglas simples.
- Es relativamente fácil de implementar.

**Desventajas**:
- Puede ser difícil de controlar y predecir el resultado final.
- Puede requerir múltiples iteraciones para alcanzar un estado estable, lo que puede ser lento.

### 4. Generación Basada en Chunks (Fragmentos)

Para mapas muy grandes, es esencial utilizar una estrategia de generación basada en chunks. En lugar de generar todo el mapa a la vez, el mapa se divide en una cuadrícula de chunks (por ejemplo, 32x32 tiles cada uno). Solo los chunks que están cerca del jugador se generan y se mantienen en memoria. A medida que el jugador se mueve, los chunks lejanos se descargan y los nuevos chunks se generan.

**Implementación**:
- El mundo se divide en una cuadrícula de chunks.
- Cada chunk se identifica por sus coordenadas en la cuadrícula de chunks (chunkX, chunkY).
- Cuando se necesita un chunk, se utiliza una función de generación procedural (por ejemplo, basada en ruido de Perlin) que toma las coordenadas del chunk y una semilla como entrada. Esto asegura que el mismo chunk siempre se genere de la misma manera.
- Se mantiene un caché de los chunks activos en memoria.

**Ventajas**:
- Permite mapas de tamaño virtualmente infinito.
- Mantiene un uso de memoria bajo y constante.
- El rendimiento es independiente del tamaño total del mapa.

**Desventajas**:
- Requiere una gestión cuidadosa de los chunks (carga, descarga, almacenamiento en caché).
- Puede haber problemas de costura en los bordes de los chunks si el algoritmo de generación no es coherente en los límites.

## Conclusión y Enfoque Recomendado

Para un roguelike espacial con un mapa grande y un vacío espacial, una combinación de estas técnicas es el enfoque más efectivo:

1. **Generación Basada en Chunks**: Es fundamental para manejar el tamaño del mapa y el rendimiento.
2. **Ruido de Perlin**: Es la mejor opción para la generación del contenido base del espacio, como la densidad de asteroides, la distribución de estrellas de fondo y la forma de las nebulosas. Su naturaleza determinista y su eficiencia para la generación de puntos individuales lo hacen ideal para la generación de chunks.
3. **Diagramas de Voronoi (Opcional)**: Pueden usarse a un nivel más alto para dividir el espacio en grandes sectores o sistemas estelares, cada uno con sus propias características generadas por ruido de Perlin.

El enfoque recomendado es comenzar con una implementación de generación basada en chunks que utilice ruido de Perlin para generar el contenido de cada chunk. Esto proporcionará una base sólida para un mapa espacial grande y explorable, y se pueden agregar capas adicionales de complejidad (como puntos de interés, eventos aleatorios, etc.) sobre esta base.

## Referencias

- [1] How I Created a Roguelike Map With Procedural Generation. Disponible en: [https://tuliomarks.medium.com/how-i-created-roguelike-map-with-procedural-generation-630043f9a93f](https://tuliomarks.medium.com/how-i-created-roguelike-map-with-procedural-generation-630043f9a93f)
- [2] Procedural Map Generation - Cogmind / Grid Sage Games. Disponible en: [https://www.gridsagegames.com/blog/2014/06/procedural-map-generation/](https://www.gridsagegames.com/blog/2014/06/procedural-map-generation/)
- [3] storing procedurally generated roguelike world into zones. Disponible en: [https://gamedev.stackexchange.com/questions/60934/storing-procedurally-generated-roguelike-world-into-zones](https://gamedev.stackexchange.com/questions/60934/storing-procedurally-generated-roguelike-world-into-zones)


