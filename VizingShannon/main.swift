//
//  main.swift
//  VizingShannon
//
//  Created by Saul Spatz on 7/2/15.
//

// This is my first Swift program.
//I am translating an edge-coloring program that I wrote in python.

import Foundation

/* There are copious comments in the python prorgam, but I'm not
reproducing them here.
*/

typealias Color = Int

// http://stackoverflow.com/questions/28489867/how-to-get-random-element-from-a-set-in-swift

func randomElement<T>(s: Set<T>) -> T {
    let n = Int(arc4random_uniform(UInt32(s.count)))
    let i = advance(s.startIndex, n)
    return s[i]
}

/*
func randomElement<T>(s: Set<T>) -> T {  // *** FOR DEBUGGING ONLY *****
    return s[advance(s.startIndex, 0)]
}
*/

class MultiGraph {
    // Have to reorganize a python code bit since we can't call methods in init
    let infile:String
    let outfile:String
    let progress:Bool
    var vertices = Array<Vertex>() // all  properties are really constants
    var edges = Array<Edge>()      // but we can't set their values in init
    var colors = Set<Color>()      // vertices and edges will be built up
    var delta = 0                  // incrementally, but once they're constructed,
    var mu = 0                     // they won't be modified
    
    init(infile:String, outfile:String, progress:Bool = true) {
        self.infile = infile
        self.outfile = outfile
        self.progress = progress
    }
    
    func initialize()->Bool {
        let reader = StreamReader(path: self.infile)
        if reader == nil {
            println("Cannot open input file \(self.infile)")
            return false
        }
        let N = reader!.nextLine()?.toInt()
        if N == nil {
            println("Bad value of N in input")
            return false
        }
        for idx in 0...N!-1 {
            self.vertices.append(Vertex(ident:idx, G:self))
        }
        var edgeCount = 0
        for line in reader! {
            let inputs = split(line){$0 == " "}.map{$0.toInt()}
            if inputs.count != 3 {
                println("Bad input line: \(line)")
                return false
            }
            let x = inputs[0]
            let y = inputs[1]
            let m = inputs[2]
            if m <= 0 {
                println("Multiplicity must be positive in \(line)")
                return false
            }
            if x >= N! || x < 0 {
                println("Bad vertex index \(x) in \(line)")
                return false
            }
            if y >= N! || y < 0 {
                println("Bad vertex index \(y) in \(line)")
                return false
            }
            for k in 1...m!{
                let e = Edge(ident:edgeCount, x:self.vertices[x!], y:self.vertices[y!],
                    m:m!, G: self)
                self.edges.append(e)
                edgeCount++
                self.vertices[x!].edges.insert(e)
                self.vertices[y!].edges.insert(e)
            }
            if m > self.mu { self.mu = m! }
        }
        for v in self.vertices {
            if v.degree > self.delta { self.delta = v.degree }
        }
        // Lesser of Shannon bound or Vizing bound
        let vizing = self.delta + self.mu
        let shannon = 3*self.delta/2
        let limit = (vizing <= shannon) ? vizing : shannon
        self.colors = Set(1...limit)
        println("|V| = \(vertices.count) |E| = \(edges.count) Delta = \(delta) mu = \(mu) k = \(limit)")
        return true
    }
    
    func edgeColor()->() {
        for e in self.edges {
            if self.progress && (e.ident % 10000==0) {
                let pct = 100*e.ident/self.edges.count
                println("Coloring edge \(e.ident) \(pct)%")
            }
            let both = e.x.missingColors.intersect(e.y.missingColors)
            if !both.isEmpty { e.colorWith(randomElement(both)) }
            else { Fan(e: e).color() }
            
        }
    }
    
    func writeColors()->Bool{
        var output:String = "N \(vertices.count) M \(edges.count) Delta \(delta) mu \(mu) colors \(colors.count)\n"
        for e in self.edges {
            let detail = "\(e.ident) \(e.x.ident) \(e.y.ident) \(e.m) \(e.color!)\n"
            output += detail
        }
        var err:NSErrorPointer = nil
        return output.writeToFile(self.outfile, atomically: false, encoding: NSUTF8StringEncoding, error: err)
    }
    
    func audit()->Bool {
        // Pre: self.writeColors has already been called
        // Assume no blank lines in either file
        struct Node{
            var degree = 0
            var colors = Set<Color>()
        }
        let inReader = StreamReader(path: self.infile)
        let outReader = StreamReader(path: self.outfile)
        if inReader == nil || outReader == nil {
            println("Failed to open file")
            return false
        }
        var outCount = 0
        let n1 = inReader!.nextLine()?.toInt()
        let line1 = split(outReader!.nextLine()!){$0 == " "}.map{$0.toInt()}
        let n = line1[1]
        let m = line1[3]
        let delta = line1[5]
        let mu = line1[7]
        let k = line1[9]
        if n1 != n {
            println("Number of vertices differ in input and output files")
            return false
        }
        var nodes = Array<Node>()
        for i in 1...n! {
            nodes.append(Node())
        }
        for line in inReader! {
            let inputs = split(line){$0 == " "}.map{$0.toInt()}
            let x = inputs[0]
            let y = inputs[1]
            let m = inputs[2]
            for j in 1...m! {
                outCount += 1
                let line1 = outReader!.nextLine()!
                let outputs = split(line1){$0 == " "}.map{$0.toInt()}
                let x1 = outputs[1]
                let y1 = outputs[2]
                let m1 = outputs[3]
                let color = outputs[4]
                if x != x1 || y != y1 || m != m1 {
                    println("Inconsistent data")
                    println("\tinput file: \(line)")
                    println("\touput file: \(line1)")
                    return false
                }
                if color < 1 || color > k {
                    println("Illegal color \(color) in output line \(outCount+1)")
                    println("\(line1)")
                    return false
                }
                nodes[x!].degree += 1
                nodes[x!].colors.insert(color!)
                nodes[y!].degree += 1
                nodes[y!].colors.insert(color!)
            }
        }
        for (idx, v) in enumerate(nodes) {
            if v.degree != v.colors.count {
                println("Duplicate colors at vertex \(idx)")
                return false
            }
        }
        return true
    }
    
    func invariant()->Bool {
        // Is the graph properly colored so far?
        // Test that for every colored edge, the color is listed at both ends
        for e in self.edges {
            if let a = e.color {
                if (!e.x.colors.contains(a) || !e.y.colors.contains(a)) {return false}
            }
        }
        // Test that for each vertex, there are no duplicate colors.
        for v in self.vertices {
            let coloredEdges = filter(v.edges){$0.color != nil}
            if v.colors.count != coloredEdges.count {
                return false
            }
            // Can't map sets -- dumb
            // Should be able to use map(coloredEdges){$0.color}
            var c = Set<Color>()
            for e in coloredEdges {
                c.insert(e.color!)
            }
            if c != v.colors {
                return false
            }
        }
        return true
    }
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
    var degree:Int {
        get {return self.edges.count}
    }
    
    var missingColors: Set<Color> {
        get {return self.G.colors.subtract(self.colors)}
    }
    
    func withColor(c:Color)->Edge? {
        return filter(self.edges){$0.color == c}[0]
    }

}

class Edge: Hashable, Equatable{
    var color:Color? = nil
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
        if let current = self.color {
            self.x.colors.remove(current)
            self.y.colors.remove(current)
        }
        self.x.colors.insert(c)
        self.y.colors.insert(c)
        self.color = c
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
    // no furher use for the fan, but this doesn't seem to be possible in Swift,
    // because I can't call any methods from init.
    // I have to call self.color
    
    let x:Vertex
    var rim = [Vertex]()
    var fan = [Edge]()
    var candidates = Set<Edge>()
    var missingColors:Set<Color>
    
    init(e:Edge) {
        self.x = (e.x.degree <= e.y.degree) ? e.x : e.y
        self.rim.append((self.x == e.x) ? e.y : e.x)
        self.fan.append(e)
        self.missingColors = self.rim[0].missingColors
        self.candidates = Set(filter(self.x.edges) {$0.color != nil})
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
            else if let idx = self.reducible() {
                self.reduce(idx)
                done = true
            }
        }
    }
    
    func nextEdge()->Edge? {
        var answer:Edge? = nil
        for e in self.candidates {
            if self.missingColors.contains(e.color!) {
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
        let xMissing = self.x.missingColors
        let yMissing = self.rim[self.rim.count-1].missingColors
        for c in xMissing.intersect(yMissing) {
            new = c
            break
        }
        let lastEdge = self.fan[self.fan.count-1]
        let old = lastEdge.color
        lastEdge.colorWith(new)
        if self.fan.count <= 1 {
            return
        }
        var idx = 0
        for (i, y) in enumerate(self.rim) {
            if y.missingColors.contains(old!) {
                idx = i
                break
            }
        }
        if self.fan.count > 1 {
            self.fan = Array(self.fan[0...idx])
            self.rim = Array(self.rim[0...idx])
            self.fold()
        }
    }
    
    func reduce(i:Int)->() {
        let yi = self.rim[i]
        let yn = self.rim[self.rim.count-1]
        let a = randomElement(yn.missingColors.intersect(yi.missingColors))
        let b = randomElement(self.x.missingColors)
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
        return z != self.x
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

func report(start:NSDate, end:NSDate, message:String)->() {
    let seconds = end.timeIntervalSinceDate(start)
    println(String(format: "%@ %.2f seconds", message, seconds))
}

// main line starts here

let args = [String](Process.arguments)
if args.count != 3 {
    println("Usage \(args[0]) infile outfile")
    exit(1)
}
var start = NSDate()
let G = MultiGraph(infile: args[1], outfile: args[2])

if !G.initialize() {
    println("Initialization failed")
    exit(1)
}

G.edgeColor()

if !G.writeColors() {
    println("Error writing output file")
    exit(1)
}

var end = NSDate()

report(start, end, "Coloring complete")

start = NSDate()
let result = G.audit()
end = NSDate()

if !result {
    report(start, end, "****Failed audit****")
}
else {
    report(start, end, "All tests passed")
}





