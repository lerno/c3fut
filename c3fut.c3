module c3fut::fut;

interface Future {
    fn any! poll(any data);
}

struct FutureDone(Future) {
    any result;
}

fn any! FutureDone.poll(&self, any data) @dynamic {
    return self.result;
}

macro Future done(value) {
    return @tclone(FutureDone{@tclone(value)});
}

struct FutureReject(Future) {
    anyfault excuse;
}

fn any! FutureReject.poll(&self, any data) @dynamic {
    return self.excuse?;
}

fn Future reject(anyfault excuse) {
    FutureReject r = {};
    r.excuse = excuse;
    return @tclone(r);
}

def FutureThenFunction = fn Future(any result);

struct FutureThen(Future) {
    Future left;
    Future right;
    FutureThenFunction f;
}

fn any! FutureThen.poll(&self, any data) @dynamic {
    if (self.left != null) {
        any result = self.left.poll(data)!;
        if (result) {
            self.right = self.f(result);
            self.left = null;
        }
        return null;
    } else {
        assert(self.right != null);
        return self.right.poll(data);
    }
}

macro Future Future.then(Future left, FutureThenFunction f) {
    return @tclone(FutureThen {
        .left = left,
        .f = f
    });
}

def FutureCatchFunction = fn Future(anyfault excuse);

struct FutureCatch(Future) {
    Future left;
    Future right;
    FutureCatchFunction f;
}

fn any! FutureCatch.poll(&self, any data) @dynamic {
    if (self.left != null) {
        any! result = self.left.poll(data);
        if (catch excuse = result) {
            self.right = self.f(excuse);
            self.left = null;
            return null;
        }
        return result;
    } else {
        assert(self.right != null);
        return self.right.poll(data);
    }
}

// NOTE: We don't really need to call it @catch (I don't remember what @ does, I think it's an
// inline macro or something?), but since catch is a C3 keyword we decided to call
// @catch. If it causes any problems in the future we should consider a different naming.
macro Future Future.@catch(Future left, FutureCatchFunction f) {
    return @tclone(FutureCatch {
        .left = left,
        .f = f
    });
}

def FutureForeverFunction = fn Future(any arg);
struct FutureForever(Future) {
    any arg;
    FutureForeverFunction make;
    Future fut;
}

fn any! FutureForever.poll(&self, any data) @dynamic {
    if (self.fut == null) self.fut = self.make(self.arg);
    any result = self.fut.poll(data)!;
    if (result != null) self.fut = null; // TODO: This leaks a bit of memory every time, because we can't customize allocators
    return null;
}

fn Future forever(FutureForeverFunction make, any arg = null)
{
    return @tclone(FutureForever {
        .arg = arg,
        .make = make,
    });
}

// TODO: future::start() should be a method of a single future and we should have a
// future combinator that accepts slice of futures. We should call it something
// like future::parallel(). Or maybe even future::collect() which returns you the
// list of future results.
fn void! start(Future[] futures) {
    bool quit = false;
    while (!quit) {
        quit = true;
        foreach (future: &futures) {
            if (future.poll(null)! == null) {
                quit = false;
            }
        }
    }
}
