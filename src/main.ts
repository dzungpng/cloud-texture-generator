import {vec2, vec3} from 'gl-matrix';
import * as Stats from 'stats-js';
import * as DAT from 'dat-gui';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';
import Icosphere from './geometry/Icosphere';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  pause: false,
  ellipsoidXRadius: 2.,
  ellipsoidYRadius: 4.,
  ellipsoidZRadius: 2.,
  horizontalStretch: 1,
  verticalStretch: 1,
  brightness: 5.
};

let square: Square;
let icosphere: Icosphere;

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');

  // set premultipliedAlpha = false and preserveDrawingBuffer = true draws the complete image
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2', {
    premultipliedAlpha: false,
    preserveDrawingBuffer: true,
  });
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to set up scene
  square = new Square(vec3.fromValues(0, 0, 0), vec2.fromValues(1, 1));
  square.create();

  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 8, controls.tesselations);
  icosphere.create();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  //renderer.setClearColor(1, 1, 1, 1);
  gl.enable(gl.DEPTH_TEST);

  // Enable alpha blending and set the percentage blending factors
  gl.enable(gl.BLEND);
  // gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); // https://stackoverflow.com/questions/19674740/opengl-es2-premultiplied-vs-straight-alpha-blending

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/ellipsoid-frag.glsl'))
  ]);

  // Save the cloud texture
  var saveCanvasImage = { 
    exportImage:function() { 
      const capturedImage = canvas.toDataURL();
      var link = document.createElement("a");

      document.body.appendChild(link); // for Firefox
  
      link.setAttribute("href", capturedImage);
      link.setAttribute("download", capturedImage);
      link.click();
    }
  };  

  // Add controls to the gui
  const gui = new DAT.GUI({ width: 300 });
  //gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'ellipsoidXRadius', 0.2, 10.0).step(0.1);
  gui.add(controls, 'ellipsoidYRadius', 0.2, 10.0).step(0.1);
  gui.add(controls, 'ellipsoidZRadius', 0.2, 10.0).step(0.1);
  gui.add(controls, 'horizontalStretch', 1, 4).step(1);
  gui.add(controls, 'verticalStretch', 1, 4).step(1);
  gui.add(controls, 'pause')
  gui.add(saveCanvasImage,'exportImage');

  var time = 0;

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    renderer.render(
      camera, 
      lambert, 
      time,
      vec3.fromValues(controls.ellipsoidXRadius, controls.ellipsoidYRadius, controls.ellipsoidZRadius), 
      vec2.fromValues(controls.horizontalStretch, controls.verticalStretch),
      controls.brightness,
      [
        icosphere,
      ]);
    if(!controls.pause)
      time++;
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
