//  Adapted from code by moriturus on 8/12/14.
//  Copyright (c) 2014-2015 moriturus. All rights reserved.
//
// Available from
//   https://github.com/moriturus/Concurrent/blob/master/Concurrent/Mutex.swift

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/**
 * POSIX thread mutex wrapper class
 */
public class Mutex {

    /// mutex object pointer
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t>

    /// attr object pointer
    private let attr: UnsafeMutablePointer<pthread_mutexattr_t>

    /**
    initializer
    */
    public init() {
        mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)

        pthread_mutexattr_init(attr)
        pthread_mutexattr_settype(attr, Int32(PTHREAD_MUTEX_RECURSIVE))
        pthread_mutex_init(mutex, attr)
    }

    /**
    deinitializer
    */
    deinit {
        pthread_mutexattr_destroy(attr)
        pthread_mutex_destroy(mutex)
    }

    /**
    lock a thread
    */
    public func lock() {
        pthread_mutex_lock(mutex)
    }

    /**
    unlock a thread
    */
    public func unlock() {
        pthread_mutex_unlock(mutex)
    }
}

/**
 * POSIX thread condition wrapper class
 */
public class Condition : Mutex {

    /// condition object pointer
    private let condition: UnsafeMutablePointer<pthread_cond_t>

    /**
    initializer
    */
    public override init() {
        condition = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: 1)

        pthread_cond_init(condition, nil)

        super.init()
    }

    /**
    deinitializer
    */
    deinit {
        pthread_cond_destroy(condition);
    }

    /**
    send a signal to the waiting thread
    - returns: true if a signal was sent
    */
    public func signal() -> Bool {
        return pthread_cond_signal(condition) == 0
    }

    /**
    wait a thread until signal()
    - returns: true if a signal was received
    */
    public func wait() -> Bool {
        return pthread_cond_wait(condition, mutex) == 0
    }
}
