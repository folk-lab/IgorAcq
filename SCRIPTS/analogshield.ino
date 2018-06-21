/* write DAC values to analogShield based on Serial commands */

#include <analogShield.h> // lots of problems here

int MAX_CMD_LENGTH = 25;
char cmd[25];
int cmdIndex;

char cmdType[3];
unsigned int channel=99;
char dacStr[10]; 
int DAC0_OFF = 179, DAC1_OFF = 42, DAC2_OFF=144, DAC3_OFF=81; // offsets in DAC units
unsigned int out0 = 32768-DAC0_OFF; // zero values for all DAC channels
unsigned int out1 = 32768-DAC1_OFF;
unsigned int out2 = 32768-DAC2_OFF;
unsigned int out3 = 32768-DAC3_OFF;
unsigned long nRead;

void setup() {
  // set all DAC channels to 0
  analog.write(out0, out1, out2, out3,true);
  
  // setup serial port
  Serial.begin(115200);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB
  }
  int serialTimeout = 250;  // milliseconds
  Serial.setTimeout(serialTimeout); 
  Serial.flush();
}

void loop() {  // main loop
  
  if (Serial.available()) { // check for anything written to serial port
    if (Serial.available()>0) {
      
      char byteIn = Serial.read();
      cmd[cmdIndex] = byteIn;
      
      if(byteIn=='\n'){
        //command finished
        cmd[cmdIndex] = '\0'; // null terminate the string
        parseCommands(cmd);
        cmdIndex = 0;
        
      }else{
        if(cmdIndex++ >= MAX_CMD_LENGTH){
          cmdIndex = 0;
        }
      }
    }

  }
  
}

void parseCommands(char* c) {
  /* 
     here are the commands I want to deal with:
     
     DAC i, val update dac channel i to val
     ADC i, N read N points from adc channel i
  */

  if(!strncmp("DAC ", c, 4)){
    // this is a DAC command
    sscanf(c, "%*s %d,%s", &channel,dacStr);
//    Serial.print(channel,DEC);
//    Serial.print(",");
//    Serial.print(stringToDAC(dacStr),DEC);
//    Serial.println("");

      if(channel==0){
        out0 = stringToDAC(dacStr, DAC0_OFF);
      }
      else if(channel==1){
        out1 = stringToDAC(dacStr, DAC1_OFF);
      }
      else if(channel==2){
        out2 = stringToDAC(dacStr, DAC2_OFF);
      }
      else if(channel==3){
        out3 = stringToDAC(dacStr, DAC3_OFF);
      }

      analog.write(out0,out1,out2,out3, true);

  channel=99; // make sure you don't set anything by accident
  memset(&dacStr[0], 0, sizeof(dacStr));
  }
  else if(!strncmp("ADC ", c, 4)){
    // this is an ADC read command
    // setup your acquisition software to read 2*N+4 bytes
    // the first 2*N bytes are the data (2 bytes per 16 bit reading)
    // the last 4 bytes are a long int giving the loop time
    sscanf(c, "%*s %d,%ld", &channel,&nRead);

    unsigned long loopStart;
    unsigned long loopTime;
    unsigned int reading;
    unsigned int temp;

    delay(10);
    loopStart = micros();
    
    for(unsigned long i = 0; i<nRead; i++){
      reading = analog.read(channel,true);
      Serial.write(reading % 256); // low bit
      Serial.write(reading / 256); // high bit
    }
    
    loopTime = micros()-loopStart;
    temp = loopTime & 0xFFFF; // send the low 16 bit integer value
    Serial.write(temp % 256); // low bit
    Serial.write(temp / 256); // high bit
    temp = loopTime >> 16; // send the higher 16 bit integer value
    Serial.write(temp % 256); // low bit
    Serial.write(temp / 256); // high bit
  }
    else if(!strncmp("ADCF ", c, 5)){
    // this is an ADC fast read command (ADCF)
    // setup your acquisition software to read 2*N+4 bytes
    // the first 2*N bytes are the data (2 bytes per 16 bit reading)
    // the last 4 bytes are a long int giving the loop time
    sscanf(c, "%*s %d,%ld", &channel,&nRead);

    unsigned long loopStart;
    unsigned long loopTime;
    unsigned int readings[nRead];
    unsigned int temp;

    delay(10);
    loopStart = micros();
    
    for(unsigned long i = 0; i<nRead; i++){
      readings[i] = analog.read(channel,true);
    }
    
    loopTime = micros()-loopStart;

   for(unsigned long i = 0; i<nRead; i++){
      Serial.write(readings[i] % 256); // low bit
      Serial.write(readings[i] / 256); // high bit
    }
    
    temp = loopTime & 0xFFFF; // send the low 16 bit integer value
    Serial.write(temp % 256); // low bit
    Serial.write(temp / 256); // high bit
    temp = loopTime >> 16; // send the higher 16 bit integer value
    Serial.write(temp % 256); // low bit
    Serial.write(temp / 256); // high bit
  }
}
unsigned int stringToDAC(char* ds, int offset){
  // convert string to float to 16-bit int
  // DAC range is +/- 5000mV
  // ds is a string giving the output in mV

  long out = round(65535*(atof(ds)*1.004+5000)/10000); // scaling factor is an average over the 4 channels
  // Serial.println(out+offset);
  
  if(out-offset>65535){
    // Serial.println("over");
    return 65535;
  }
  else if(out-offset<0){
    // Serial.println("under");
    return 0;
  }
  else{
  return out-offset;
  }
}

