import ComposableArchitecture
import XCTest

class NavigationIDTests: XCTestCase {
  func testBasics() {
    let trie = _Trie()
    trie.insert(word: "car")
    trie.insert(word: "care")
    trie.insert(word: "carrot")
    trie.insert(word: "carb")
    trie.insert(word: "carburized")
    trie.insert(word: "cardboard")
    trie.insert(word: "carrousel")
    trie.insert(word: "carries")

    print(trie.findWordsWithPrefix(prefix: "carb"))
    print(trie.findWordsWithPrefix(prefix: "carr"))
    print(trie.findWordsWithPrefix(prefix: "car"))
    print(trie.findWordsWithPrefix(prefix: "cat"))

    dump(trie)
    print("!!!")
  }
}

/*
 Trie<AnyID, [AnyHashable: Set<AnyCancellable>]>
 .insert(navigationID, [:])
 .modify(navigationID, default: [:]) {
   $0
 }

 trie[navigationID, default: [:]][id, default: []].insert(cancellable)
 trie.removeAll(navigationID)


 */


class TrieNode<Key: Hashable, Value> {
  var key: Key
  var value: Value
  var parent: TrieNode<Key, Value>?
  var children: [Key: TrieNode<Key, Value>] = [:]
  var state: State = .unterminated

  enum State {
    case terminated(Value)
    case unterminated
  }

  init(key: Key, value: Value) {
    self.key = key
    self.value = value
  }

  func add(key: Key, value: Value) {

  }
}



class _TrieNode<T: Hashable> {
  var value: T?
  var parentNode: _TrieNode?
  var children: [T: _TrieNode] = [:]
  var isTerminating = false
  var isLeaf: Bool {
    return children.count == 0
  }

  init(value: T? = nil, parentNode: _TrieNode? = nil) {
    self.value = value
    self.parentNode = parentNode
  }

  func add(value: T) {
    guard children[value] == nil else {
      return
    }
    children[value] = _TrieNode(value: value, parentNode: self)
  }
}

class _Trie {

  public var count: Int {
    return wordCount
  }

  fileprivate let root: _TrieNode<Character>
  fileprivate var wordCount: Int

  init() {  // the initialization of the root empty node
    root = _TrieNode<Character>()
    wordCount = 0
  }
}
extension _Trie {

  func insert(word: String) {
    guard !word.isEmpty else {
      return
    }

    var currentNode = root

    for character in word.lowercased() {  // 1
      if let childNode = currentNode.children[character] {
        currentNode = childNode
      } else {
        currentNode.add(value: character)
        currentNode = currentNode.children[character]!
      }
    }

    guard !currentNode.isTerminating else {  // 2
      return
    }

    wordCount += 1

    currentNode.isTerminating = true
  }
}

extension _Trie {

  func findWordsWithPrefix(prefix: String) -> [String] {
    var words = [String]()
    let prefixLowerCased = prefix.lowercased()
    if let lastNode = findLastNodeOf(word: prefixLowerCased) { //1
      if lastNode.isTerminating { // 1.1
        words.append(prefixLowerCased)
      }
      for childNode in lastNode.children.values { //2
        let childWords = getSubtrieWords(rootNode: childNode, partialWord: prefixLowerCased)
        words += childWords
      }
    }
    return words // 3
  }

  private func findLastNodeOf(word: String) -> _TrieNode<Character>? { // this just check is the prefix exist in the Trie
    var currentNode = root
    for character in word.lowercased() {
      guard let childNode = currentNode.children[character] else { // traverse the Trie with each of prefix character
        return nil
      }
      currentNode = childNode
    }
    return currentNode
  }
}

extension _Trie {
  fileprivate func getSubtrieWords(rootNode: _TrieNode<Character>, partialWord: String) -> [String] {
    var subtrieWords = [String]()
    var previousLetters = partialWord
    if let value = rootNode.value { // 1
      previousLetters.append(value)
    }
    if rootNode.isTerminating { //2
      subtrieWords.append(previousLetters)
    }
    for childNode in rootNode.children.values { //3
      let childWords = getSubtrieWords(rootNode: childNode, partialWord: previousLetters)
      subtrieWords += childWords
    }
    return subtrieWords
  }
}
