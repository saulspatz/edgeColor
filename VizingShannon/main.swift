//
//  main.swift
//  VizingShannon
//
//  Created by Saul Spatz on 7/2/15.
//  Copyright (c) 2015 Saul Spatz. All rights reserved.
//

// This is my first Swift program.  
//I am translating an edge-coloring program that I wrote in python.

import Foundation

/* There are copious comments in the pythion prorgam, but I'm not
reproducing them eher.
*/

typealias Color = Int

// http://stackoverflow.com/questions/28489867/how-to-get-random-element-from-a-set-in-swift
func randomElement<T>(s: Set<T>) -> T {
    let n = Int(arc4random_uniform(UInt32(s.count)))
    let i = advance(s.startIndex, n)
    return s[i]
}

class MultiGraph {
    var colors = Set<Color>()
    
}

class Vertex: Hashable, Equatable {
    let ident: Int  // for debugging
    var edges = Set<Edge>()
    var colors = Set<Color>()
    var hashValue:Int {return self.ident}
    let G:MultiGraph
    init(ident: Int, G:MultiGraph) {
        self.ident = ident
        self.G = G
    }
    func present(c:Color)->Bool {
        return self.colors.contains(c)
    }
    func missing(c:Color)->Bool {
        return !self.present(c)
    }
    func degree()->Int {
        return self.edges.count
    }
    /*
    func missingColors()->Set<Color> {
        return self.G.colors.subtract(self.colors)
    }
    */
    var missingColors: Set<Color> {
        get {
            return self.G.colors.subtract(self.colors)
        }
    }
    func withColor(c:Color)->Edge? {
        var answer:Edge? = nil
        for e in self.edges{
            if e.color == c {
                answer = e
                break
            }
        }
        return answer
    }
}

class Edge: Hashable, Equatable{
    var color:Color = 0  // 0 means uncolored
    let ident:Int
    var hashValue:Int {return self.ident}
    let x:Vertex   // endpoints
    let y:Vertex
    let m:Int     // multiplicty
    let G:MultiGraph
    init(ident:Int, x:Vertex, y:Vertex, m:Int, G:MultiGraph) {
        self.ident = ident
        self.x = x
        self.y = y
        self.m = m
        self.G = G
    }
    func colorWith(c:Color) {
        self.x.colors.remove(self.color)
        self.x.colors.insert(c)
        self.y.colors.remove(self.color)
        self.y.colors.insert(c)
    }
}

func==(lhs:Edge, rhs:Edge)->Bool {
    return lhs.ident == rhs.ident
}

func==(lhs:Vertex, rhs:Vertex)->Bool {
    return lhs.ident == rhs.ident
}

class Fan {
    // Pre: e is an uncolored edge, and there is no color missing
    // at both endpoints of e.
    // In the python program, calling Fan(e) properly colored e, and there was 
    // no furher use for the fan, but this doesn't seem to be possible in Swift.
    // I have to call self.colorEdge
    
    let x:Vertex
    var rim = [Vertex]()
    var fan = [Edge]()
    var candidates = Set<Edge>()
    var missingColors:Set<Color>
    
    init(e:Edge) {
        self.x = e.x.degree() <= e.y.degree() ? e.x : e.y
        self.rim.append(self.x == e.x ? e.y : e.x)
        self.fan.append(e)
        self.missingColors = self.rim[0].missingColors
        
        // No set comprehensions damn it!
        
        for e in self.x.edges {
            if e.color != 0 {
                self.candidates.insert(e)
            }
        }
    }
    
    func color()->() {
        var done = false
        while !done {
            var f = self.nextEdge()
            self.append(f!)
            var y = self.rim[self.rim.count-1]  // negative indices are sorely missed!
            if  !y.missingColors.isDisjointWith(self.x.missingColors) {
                self.fold()
                done = true
            }
            else {
                var idx:Int? = self.reducible()
                if idx != nil {
                    self.reduce(idx!)
                    done = true
                }
            }
        }
    }
    
    func nextEdge()->Edge? {
        var answer:Edge? = nil
        for e in self.candidates {
            if self.missingColors.contains(e.color) {
                answer = e  // self.append will remove e from self.candidates
                break
            }
        }
        return answer
    }
    
    func append(e:Edge)->() {
        self.fan.append(e)
        self.candidates.remove(e)
        var y = (e.x == self.x) ? e.y : e.x
        self.rim.append(y)
        self.missingColors.unionInPlace(y.missingColors)
    }
    
    func reducible()->Int? {
        var answer:Int? = nil
        let last = self.rim[self.rim.count-1]
        var missing = last.missingColors
        for (idx, y) in enumerate(self.rim) {
            if !missing.isDisjointWith(y.missingColors) && y != last{
                answer = idx
                break
            }
        }
        return answer
    }
    
    func fold()->() {
        var new:Color = 0
        var lastVertex = self.rim[self.rim.count-1]
        for c in self.x.missingColors.intersect(lastVertex.missingColors) {
            new = c
            break
        }
        var lastEdge = self.fan[self.fan.count-1]
        var old = lastEdge.color
        lastEdge.colorWith(new)
        if self.fan.count <= 1 {
            return
        }
        var idx:Int = 0
        for (i, y) in enumerate(self.rim) {
            if y.missingColors.contains(old) {
                idx = i
                break
            }
        }
        self.fan = Array(self.fan[0...idx])
        self.rim = Array(self.rim[0...idx])
        self.fold()
    }
    
    func reduce(i:Int)->() {
        var yi = self.rim[i]
        var yn = self.rim[self.rim.count-1]
        var a = randomElement(yn.missingColors.intersect(yi.missingColors))
        var b = randomElement(self.x.missingColors)
        if self.chain(yi, a: a, b: b, x: x) {  // Objective-C influence -- barf
            self.fan=Array(self.fan[0...i])
            self.rim = Array(self.rim[0...i])
            self.fold()
        }
        else {
            self.chain(yn, a: a, b: b, x: x)   // re-barf
            self.fold()
        }
    }
    
    func chain(y:Vertex, a:Color, b:Color, x:Vertex)->Bool {
        var current = b
        var z = y
        var chain = [Edge]()
        while z.colors.contains(current) {
            let f = z.withColor(current)
            let e = f!
            chain.append(e)
            z = (e.x == z) ? e.y : e.x
            current = (current == a) ? b : a
        }
        if z != self.x {
            self.swapColors(chain, a: a, b: b, first: y, last: z)
        }
        return z != x
    }
    
    func swapColors(chain:[Edge], a:Color, b:Color, first:Vertex, last:Vertex)->(){
        for e in chain {
            e.color = (e.color == b) ? a : b
        }
        for (v, e) in [(first, chain[0]), (last, chain[chain.count-1])] {
            var  (new, old) = (e.color == a) ? (a, b) : (b, a)
            v.colors.insert(new)
            v.colors.remove(old)
        }
    }
}