/*
China High-Speed Rail Animation by Yannick Brouwer 2022
 www.yannickbrouwer.nl 
 
Requirements:
Unfolding Maps library 0.99b
https://github.com/yannickbrouwer/ancestors-migration-visualization/blob/master/Unfolding_for_processing_0.9.9beta.zip
 
 Attribution & thanks to: 
 Kejing Peng collected the timetable and station data on this cool website:
 http://cnrail.geogv.org
 
 Heads-up, because I'm not sure who the original rights owner is of the train data, I included only a small sample to show you how this software works. 
  
 Will Geary created the Transit Flow animation that I used as a basis:
 https://github.com/transitland/transitland-processing-animation
 
 Till Nagel created the Unfolding Maps library:
 http://unfoldingmaps.org/
 
 Juan Francisco Saldarriaga work was useful as reference:
 https://github.com/juanfrans-courses/DataScienceSocietyWorkshop
 
 Basemap made with Mapbox Studio  with special thanks to the Open Street Map contributors.
 https://studio.mapbox.com/
 
 Controls
 'Spacebar' is pause and play
 'k' is add a keyframe, it adds the current position and zoomlevel of your screen.
 's' is save keyframes, next time you open the sketch it will load these externally from keyframes.txt
 + and - zoom in and out
 Cursors keys, move around the map
 
 Lef mouse click on map: drag map
 Left mouse on click on timeline: scroblle timeline
 Right mouse click on timeline: delete nearby keyframe
 Scroll mouse zoom in and out
 */

////// Libraries ///////

// Import Java utilities
import java.util.concurrent.TimeUnit;
import java.util.Date;
import java.text.SimpleDateFormat;
import java.io.FileWriter;
import java.io.*;

// Import Unfolding Maps
import de.fhpotsdam.unfolding.*;
import de.fhpotsdam.unfolding.core.*;
import de.fhpotsdam.unfolding.data.*;
import de.fhpotsdam.unfolding.events.*;
import de.fhpotsdam.unfolding.geo.*;
import de.fhpotsdam.unfolding.interactions.*;
import de.fhpotsdam.unfolding.mapdisplay.*;
import de.fhpotsdam.unfolding.mapdisplay.shaders.*;
import de.fhpotsdam.unfolding.marker.*;
import de.fhpotsdam.unfolding.providers.*;
import de.fhpotsdam.unfolding.texture.*;
import de.fhpotsdam.unfolding.tiles.*;
import de.fhpotsdam.unfolding.ui.*;
import de.fhpotsdam.unfolding.utils.*;
import de.fhpotsdam.utils.*;
UnfoldingMap map;

// Basemap providers
AbstractMapProvider provider1;
AbstractMapProvider provider2;
AbstractMapProvider provider3;
AbstractMapProvider provider4;
AbstractMapProvider provider5;
AbstractMapProvider provider6;
AbstractMapProvider provider7;
AbstractMapProvider provider8;
AbstractMapProvider provider9;


String provider1Attrib;
String provider2Attrib;
String provider3Attrib;
String provider4Attrib;
String provider5Attrib;
String provider6Attrib;
String provider7Attrib;
String provider8Attrib;
String provider9Attrib;
String provider0Attrib;

String attrib;
Float attribWidth;


////// Files ///////
String directoryName = "${DIRECTORY_NAME}";
String date = "${DATE}";
String inputFile = "../data/chinese_rail.csv";
FileWriter fw;
BufferedWriter bw;


////// Settings ///////
int totalFrames = 600; // Amount of frames for final animation. 60fps * 10 seconds of video. 

// Center of the location and zoomlevel at start of the animation.
// You could save a nice keyframe and then open keyframes.txt to find the coordinates and keyframe to enter here or you can find the lat and long for any location online.
Location center = new Location(34.062748, 104.56538);
Integer zoom_start = 5;

// Date Format
String date_format = "dd/MM/yyyy";
String date_display = "yyyy";
String day_format = "EEEE";
String time_format = "HH:mm";

// Define date format of raw data
SimpleDateFormat myDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
SimpleDateFormat hour = new SimpleDateFormat("h:mm a");
//SimpleDateFormat day = new SimpleDateFormat("MMMM dd, yyyy");
SimpleDateFormat weekday = new SimpleDateFormat("EEEE");

////// Video Recording ///////

// Every frame of the animation is saved to a .png file in the output folder. You can use the Processing Moviemaker (Tools>Movie Maker) or video editting software to stitch these images to an animation. Framerate is 60 frames per second)
// Set to true when you want to save the final sequence.
boolean recording = false;

// If firstPass is true, the animation will first run once to preload the map tiles. startRecording should be false on default,
boolean firstPass = true;

// This one is used to determine whether the recording starts right away or after a first pass. Best to leave it on false. It's state is determined within setup.
boolean startRecording = false;

////// Variables ///////
ArrayList<Trips> trips = new ArrayList<Trips>();
ArrayList<String> train_type = new ArrayList<String>();

long totalSeconds;
Table tripTable;

int counterFrames = 0;
int prevCounterFrames = 0;

// Keyframes
// This is a list that holds all the current keyframes. On start imports keyframes from keyframes.txt, it holds any changes made to keyframes by the user and by pressing 'S' the latest state is saved to keyframes.txt
StringList allKeyFrames = new StringList();
ArrayList<keyFrame> keyframes =new ArrayList<keyFrame>();

int keyframeIndex;
int indicator;
int currentLocation = 0;
int prevNearest = 10000;

ScreenPosition startPos;
ScreenPosition endPos;
Location startLocation;
Location endLocation;
Date minDate;
Date maxDate;
Date startDate;
Date endDate;
Date thisStartDate;
Date thisEndDate;



////// UI ///////

// Determine the size of the UI on the bottom of the screen.
int boxX = 0;
int boxY = 1080;
int boxW = 1920;
int boxH = 60;

// Left and right X coordinate of the timeline
int tlA = 60;
int tlB = boxW-60;


Integer screenfillalpha = 0;
PImage pointer;

boolean pause = false;
boolean endAnimation = false; // Is turned on at end of timeline to stop animation.

Float firstLat;
Float firstLon;
color c;

//Assets (fonts & icons)
PFont fontInter;
PImage playImg;
PImage pauseImg;
PImage replayImg;

PFont mono;

boolean scrubbing = false;

Location scrubRestrict = new Location(52.5f, 13.4f);

void setup() {
  mono = createFont("RobotoMono-Regular.ttf", 48);
  // Determine the pixeldensity of your display.
  // If you get an error, replace displayDensity() with 1 for normal density or 2 for high density displays.
  pixelDensity(displayDensity());


  // FullHD resolution plus 60px vertical space for the timeline UI. Adjust when this doesn't fit your screen. Apparently when the windows is partially outside of the boundaries of your screen, that part isn't saved to the PNG's. This is a known issue with the P3D renderer in Processing.
  size(1920, 1140, P3D);

  // This makes sure that the screen only gets recorded after a first buffer pass when 'firstPass' = true. If firstPass is off it will start recording directly.
  if (firstPass) {
    startRecording = false;
  } else {
    startRecording = true;
  }

  // Load image assets for the interface
  playImg = loadImage("assets/play.png");
  pauseImg = loadImage("assets/pause.png");
  replayImg = loadImage("assets/replay.png");
  pointer = loadImage("assets/label.png");

  // Import keyframes from external textfile and save them in the allKeyFrames list
  String[] lines = loadStrings("data/keyframes.txt");

  for (int i = 0; i < lines.length; i++) {
    println(lines[i]);
    allKeyFrames.append(lines[i]);

    String[] list = split(lines[i], ',');

    keyframes.add(new keyFrame(int(trim(list[0])), float(trim(list[1])), float(trim(list[2])), int(trim(list[3]))));
  }

  // Mapproviders
  provider1 = new StamenMapProvider.TonerLite();
  provider2 = new StamenMapProvider.TonerBackground();
  provider3 = new CartoDB.DarkMatterNoLabels();
  provider4 = new CartoDB.Positron();
  provider5 = new OpenStreetMap.OpenStreetMapProvider();
  provider6 = new OpenStreetMap.OSMGrayProvider();
  provider7 = new EsriProvider.WorldStreetMap();
  provider8 = new EsriProvider.DeLorme();
    //I used the provider below to implement the custom Mapbox Studio map. You can add your own by going to your map in Mapbox studio. Go to 'Share', click 'Third Party', select 'Carto'  from the drop down and copy the integration URL. 
    //Replace the integration URL with URL below and remove the // before the line. By pressing the'9' while running the program you can see this map.
  //provider9 = new MapBox.CustomMapBoxProvider("URL");

//This program does not add the attribution on top of the video but make sure you add the right atrribution to the video before sharing.
  provider1Attrib = "Stamen Design";
  provider2Attrib = "Stamen Design";
  provider3Attrib = "Carto";
  provider4Attrib = "Carto";
  provider5Attrib = "OpenStreetMap";
  provider6Attrib = "OpenStreetMap";
  provider7Attrib = "ESRI";
  provider8Attrib = "ESRI";
  provider9Attrib = "Mapbox";


  smooth();

  loadData();

  // Choose the default mapprovider
  map = new UnfoldingMap(this, 0, 0, width, height-60, provider3);
  MapUtils.createDefaultEventDispatcher(this, map);

  // Tweening makes transitions between locations and zoomlevels smooth
  //map.setTweening(true);

  // Start at zoomlevel and location as determined in variable at the top of this file.
  map.zoomAndPanTo(zoom_start, center);

  attrib = "Basemap by " + provider3Attrib;
  attribWidth = textWidth(attrib);

  // Fonts and icons
  fontInter  = loadFont("Inter-Medium-48.vlw");
}






void draw() {
  if (pause) {
  } else {
    // This is the timer for the animations, when this number increase the animation moves forward.
    counterFrames++;
  }


  map.draw();
  noStroke();

  // Handle time
  float epoch_float = map(counterFrames, 0, totalFrames, int(minDate.getTime()/1000), int(maxDate.getTime()/1000));
  int epoch = int(epoch_float);

  String date = new java.text.SimpleDateFormat(date_display).format(new java.util.Date(epoch * 1000L));
  String day = new java.text.SimpleDateFormat(day_format).format(new java.util.Date(epoch * 1000L));
  String time = new java.text.SimpleDateFormat(time_format).format(new java.util.Date(epoch * 1000L));

  // Enables scrubbing through the timeline using the mouse
  if (mouseX>60&&mouseX<(boxX+boxW)&&mouseY>boxY&&mouseY<boxY+boxH) {
    float mouseCursor = map(mouseX, tlA, tlB, 0, totalFrames);
    if (mousePressed && ( mouseButton == LEFT)) {
      counterFrames = int(mouseCursor);
      scrubbing = true;
      scrubRestrict = new Location(map.getCenter());
    }
  }


  if (scrubbing) {
    map.setPanningRestriction(scrubRestrict, 0.0);
  } else {
    map.setPanningRestriction(map.getCenter(), 50000);
  }


  // Train colors
  noStroke();
  for (int i=0; i < trips.size(); i++) {

    Trips trip = trips.get(i);
    String train = train_type.get(i);

    switch(train) {
    case "G":
      c = #FFDFA9;
      break;
    case "D":
      c = #F07B7B;
      break;
    case "C":
      c = #0A83C9;
      break;
    }

    trip.plotMove();
  }

  //Draw Controls & Timeline
  fill(40);
  rect(boxX, boxY, boxX+boxW, boxY+boxH);
  strokeWeight(1);
  stroke(50);
  line(boxX, boxY, boxX+boxW, boxY);
  float cursor = map(counterFrames, 0, totalFrames, tlA, tlB);
  strokeWeight(2);
  stroke(160);
  line(tlA, boxY+(boxH/2), tlB, boxY+(boxH/2));
  stroke(200);
  line(cursor, boxY+(boxH/2)-10, cursor, boxY+(boxH/2)+10);


  // Timeblock
  fill(255, 255);
  noStroke();
  rect(56, 56, 190, 80);
  fill(50, 255);

  textFont(mono);
  textSize(48);
  textAlign(LEFT);
  text(time, 79, 113);




  // Show mapprovider attribution
  fill(120, 255);
  textSize(10);
  textAlign(CENTER);
  text(attrib, width/2, height-10);


  // Stop animation at the end
  if (counterFrames>=totalFrames) {
    counterFrames = totalFrames;
    image(replayImg, 0, boxY, 60, 60);
    pause = true;
    endAnimation = true;
  } else {
    if (pause) {
      image(playImg, 0, boxY, 60, 60);
    } else {
      image(pauseImg, 0, boxY, 60, 60);
    }
  }

  for (int i = 0; i < keyframes.size(); i++) {
    keyframes.get(i).update();
  }



  if (recording) {
    // Frames sometimes are not properly rendered at the time of recording. This enables a firstpass to prerender the map tiles before starting with saving.
    if (firstPass && counterFrames > (totalFrames-2)) {
      counterFrames = -20;
      firstPass = false;
      map.zoomAndPanTo(zoom_start, center);
      startRecording = true;
    }

    if (startRecording) {
      // Save each individual frame of the animation.
      PImage frameSave = get(0, 0, 1920, 1080);
      String frameNumber = nf(counterFrames, 4);

      // Only save when the current frame is different than the previous frame. Prevents endless saving when the animation is paused.
      if (counterFrames != prevCounterFrames&&counterFrames>=0) {
        frameSave.save("output/frame" + frameNumber + ".png");
      }
    }
  }

  prevCounterFrames = counterFrames;
}

class keyFrame {
  Location x;
  int keyframe;
  int zoomlevel;

  keyFrame(int kf, float lat, float lon, int zl) {
    x = new Location(lat, lon);
    keyframe = kf;
    zoomlevel = zl;
  }

  void update() {

    // When the internal animation counter corresponds with the timestamp of a keyframe the frame is zoomed and panned to the right location and zoomlevel
    if (keyframe==counterFrames) {
      map.zoomAndPanTo(zoomlevel, x);
    }
    // Used to show the keyframe pointer at the right position on the timeline.
    float kfTL = map(keyframe, 0, totalFrames, tlA, tlB);
    image(pointer, kfTL-pointer.width/4, boxY-8+(boxH/2)-pointer.height/2, pointer.width/2, pointer.height/2);
  }
  // Find the closest keyframe to the pointer on the timeline. Is used to delete a keyframe with right click.
  void getNearby() {
    keyframeIndex = abs(keyframe - counterFrames);
  }
}

class Trips {
  int tripFrames;
  int startFrame;
  int endFrame;
  Location start;
  Location end;
  Location currentLocation;
  ScreenPosition currentPosition;
  int s;

  // class constructor
  Trips(int duration, int start_frame, int end_frame, Location startLocation, Location endLocation) {

    tripFrames = duration;
    startFrame = start_frame;
    endFrame = end_frame;
    start = startLocation;
    end = endLocation;
  }

  // function to draw each trip
  void plotMove() {
    if (counterFrames >= startFrame && counterFrames < endFrame) {
      float percentTravelled = (float(counterFrames) - float(startFrame)) / float(tripFrames);

      currentLocation = new Location(

        // Lerp is a function for linear interpolation between two points. It will find a point between two coordinates based on a percentage.

        //location data was a bit off. I adjusted it.
        lerp(start.x-1.2, end.x-1.2, percentTravelled),
        lerp(start.y+0.8, end.y+0.8, percentTravelled));

      currentPosition = map.getScreenPosition(currentLocation);

      // In that area you can change the size of the circles for each zoomlevel. I decided to keep them the same for every zoomlevel.
      float z = map.getZoom();

      if (z <= 32.0) {
        s = 6;
      } else if (z == 64.0) {
        s = 6;
      } else if (z == 128.0) {
        s = 6;
      } else if (z == 256.0) {
        s = 6;
      } else if (z == 512.0) {
        s = 6;
      } else if (z == 1024.0) {
        s = 6;
      } else if (z == 2048.0) {
        s = 6;
      } else if (z == 4096.0) {
        s = 6;
      } else if (z == 8192.0) {
        s = 6;
      } else if (z >= 16384.0) {
        s = 6;
      }
      fill(c, 20);
      ellipse(currentPosition.x, currentPosition.y, 6, 6);
      fill(c, 255);
      ellipse(currentPosition.x, currentPosition.y, 4, 4);
    }
  }
}

void loadData() {
  // Handles importing the dataset
  tripTable = loadTable(inputFile, "header");
  println(str(tripTable.getRowCount()) + " records loaded...");

  // Calculate min start time and max end time (dataset must be sorted ascending)
  String first = tripTable.getString(0, "start_time");
  String last = tripTable.getString(tripTable.getRowCount()-1, "end_time");

  println("Start time: ", first);
  println("End time: ", last);

  try {
    minDate = myDateFormat.parse(first); //first date
    maxDate = myDateFormat.parse(last); //latest date
    totalSeconds = int(maxDate.getTime()/1000) - int(minDate.getTime()/1000);
  }
  catch (Exception e) {
    println("Unable to parse date stamp");
  }
  println("Min starttime:", minDate, ". In epoch:", minDate.getTime()/1000);
  println("Max starttime:", maxDate, ". In epoch:", maxDate.getTime()/1000);
  println("Total seconds in dataset:", totalSeconds);
  println("Total frames:", totalFrames);

  firstLat = tripTable.getFloat(0, "start_lat");
  firstLon = tripTable.getFloat(0, "start_lon");

  for (TableRow row : tripTable.rows()) {
    String train = row.getString("train");
    train_type.add(train);

    // The animation uses a row called "duration" in the dataset. This is the amount of seconds between the end and start day within a row.
    // This can be calculated in Google Sheets by calculating end minus begin.
    int tripduration = row.getInt("duration");
    int duration = round(map(tripduration, 0, totalSeconds, 0, totalFrames));

    try {
      thisStartDate = myDateFormat.parse(row.getString("start_time"));
      thisEndDate = myDateFormat.parse(row.getString("end_time"));
    }
    catch (Exception e) {
      println("Unable to parse destination");
    }

    int startFrame = floor(map(thisStartDate.getTime()/1000, minDate.getTime()/1000, maxDate.getTime()/1000, 0, totalFrames));
    int endFrame = floor(map(thisEndDate.getTime()/1000, minDate.getTime()/1000, maxDate.getTime()/1000, 0, totalFrames));
    
    float startLatAdjust = row.getFloat("start_lat");
    float startLonAdjust = row.getFloat("start_lon");

    float endLatAdjust = row.getFloat("end_lat");
    float endLonAdjust = row.getFloat("end_lon");


    float startLat = ((startLatAdjust-18.171460)*0.99)+18.171460;
    float startLon = startLonAdjust;
    
    float endLat = ((endLatAdjust-18.171460)*0.99)+18.171460;
    float endLon = endLonAdjust;
    startLocation = new Location(startLat, startLon);
    endLocation = new Location(endLat, endLon);
    trips.add(new Trips(duration, startFrame, endFrame, startLocation, endLocation));
  }
}

void mouseReleased() {

  scrubbing = false;

  // Pause and play when clicking the pause/play button
  if (mouseX>0&&mouseX<60&&mouseY>boxY&&mouseY<height) {
    if (pause==true) {

      // Restart when animation is finished
      if (endAnimation) {
        map.zoomAndPanTo(zoom_start, center);
        delay(500);
        endAnimation = false;
        counterFrames = 0;
      }

      pause = false;
    } else {
      pause = true;
    }
  }

  // Click anywhere on the timeline to position the cursor there.
  if (mouseX>60&&mouseX<(boxX+boxW)&&mouseY>boxY&&mouseY<boxY+boxH) {
    float mouseCursor = map(mouseX, tlA, tlB, 0, totalFrames);

    // Right Click near a keyframe on the timeline to remove the closest keyframe.
    if (mouseButton == RIGHT) {

      if (keyframes.size()>0) {
        counterFrames = int(mouseCursor);
        for (int i = 0; i < keyframes.size(); i++) {

          keyframes.get(i).getNearby();

          if (keyframeIndex<=prevNearest) {
            prevNearest = keyframeIndex;
            indicator = i;
          }

          println(i + " "  + keyframeIndex);
        }

        println(indicator + " "  + prevNearest);


        keyframes.remove(indicator);
        allKeyFrames.remove(indicator);

        indicator = 0;
        prevNearest = 10000;
      }
    }
  }
}

void keyPressed() {
  if (key == ' ') {
    if (pause==true) {
      pause = false;
    } else {
      pause = true;
    }
  }


  if (key == 'k') {
    // Save the current position, zoomlevel and postion on the timeline as new keyframe.
    String loc;

    println(map.getCenter().getLat());
    loc = (counterFrames+","+map.getCenter().getLat()+","+map.getCenter().getLon()+","+map.getZoomLevel());

    allKeyFrames.append(loc);
    keyframes.add(new keyFrame(counterFrames, map.getCenter().getLat(), map.getCenter().getLon(), map.getZoomLevel()));
  }
  if (key == 's') {

    // By pressing S you save the current keyframes to a text file. Next time you open the sketch it will import the keyframes externally.
    String[] save = new String[allKeyFrames.size()];
    for (int i=0; i < allKeyFrames.size(); i++) {

      save[i] = allKeyFrames.get(i);
    }
    saveStrings("data/keyframes.txt", save);
  }

  // Use 0-9 and q,w,e,r,t,y,u keys to change the type of map in the background.
  if (key == '1') {
    map.mapDisplay.setProvider(provider1);
    attrib = "Basemap by " + provider1Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '2') {
    map.mapDisplay.setProvider(provider2);
    attrib = "Basemap by " + provider2Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '3') {
    map.mapDisplay.setProvider(provider3);
    attrib = "Basemap by " + provider3Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '4') {
    map.mapDisplay.setProvider(provider4);
    attrib = "Basemap by " + provider4Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '5') {
    map.mapDisplay.setProvider(provider5);
    attrib = "Basemap by " + provider5Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '6') {
    map.mapDisplay.setProvider(provider6);
    attrib = "Basemap by " + provider6Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '7') {
    map.mapDisplay.setProvider(provider7);
    attrib = "Basemap by " + provider7Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '8') {
    map.mapDisplay.setProvider(provider8);
    attrib = "Basemap by " + provider8Attrib;
    attribWidth = textWidth(attrib);
  } else if (key == '9') {
    map.mapDisplay.setProvider(provider9);
    attrib = "Basemap by " + provider9Attrib;
    attribWidth = textWidth(attrib);
  } 
}
