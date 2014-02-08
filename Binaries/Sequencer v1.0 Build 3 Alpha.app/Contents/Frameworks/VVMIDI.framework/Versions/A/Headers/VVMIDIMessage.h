
#import <Cocoa/Cocoa.h>
#import <CoreMIDI/CoreMIDI.h>



@interface VVMIDIMessage : NSObject <NSCopying> {
	Byte			type;
	Byte			channel;
	Byte			data1;		//	usually controller/note #
	Byte			data2;		//	usually controller/note value
	//	array of NSNumbers, or nil if this isn't a sysex message
	//	DOES NOT CONTAIN SYSEX START/STOP STATUS BYTES (0xF0 / 0xF7)
	NSMutableArray	*sysexArray;
    uint64_t        timestamp; // timestamp that message should be sent. eg, could use AudioGetCurrentHostTime()
}

+ (id) createWithType:(Byte)t channel:(Byte)c timestamp:(uint64_t)time;
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(uint64_t)time;
+ (id) createWithSysexArray:(NSMutableArray *)s timestamp:(uint64_t)time;
- (id) initWithType:(Byte)t channel:(Byte)c timestamp:(uint64_t)time;
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(uint64_t)time;
- (id) initWithSysexArray:(NSMutableArray *)s timestamp:(uint64_t)time;

- (NSString *) description;
- (NSString *) lengthyDescription;

- (Byte) type;
- (void) setType:(Byte)newType;
- (Byte) channel;
- (void) setData1:(Byte)newData;
- (Byte) data1;
- (void) setData2:(Byte)newData;
- (Byte) data2;
- (NSMutableArray *) sysexArray;
- (void) setTimestamp:(uint64_t)newTimestamp;
- (uint64_t) timestamp;

@end