// -*- mode: swift; swift-mode:basic-offset: 2; -*-
// Copyright © 2016-2017 Massachusetts Institute of Technology, All rights reserved.

import Foundation

let kDefaultPlaceholderColor = UIColor(red: 0, green: 0, blue: 25/255, alpha: 0.22)

fileprivate protocol TextBoxDelegate: AbstractMethodsForTextBox, UITextFieldDelegate, UITextViewDelegate {
}

fileprivate class TextBoxAdapter: NSObject, TextBoxDelegate {
  fileprivate let _field = UITextField(frame: CGRect.zero)
  fileprivate let _view = UITextView(frame: CGRect.zero)
  fileprivate let _wrapper = UIView(frame: CGRect.zero)
  fileprivate var _numbersOnly = false
  
  private var _multiLine = false
  private var _empty = true

  fileprivate override init() {
    super.init()
    _field.translatesAutoresizingMaskIntoConstraints = false
    _view.translatesAutoresizingMaskIntoConstraints = false
    _wrapper.translatesAutoresizingMaskIntoConstraints = false
    _view.textContainerInset = .zero
    _view.textContainer.lineFragmentPadding = 0
    _view.isSelectable = true
    _view.isEditable = true
    _view.delegate = self
    _field.delegate = self
    // Set up the minimum size constraint for the UITextView
    let heightConstraint = _view.heightAnchor.constraint(greaterThanOrEqualToConstant: 20)
    heightConstraint.priority = UILayoutPriority.defaultHigh
    _view.addConstraint(heightConstraint)
    _view.isScrollEnabled = false
    let selector = #selector(dismissKeyboard)
    _view.inputAccessoryView = getAccesoryView(selector)
    _field.inputAccessoryView = getAccesoryView(selector)

    // We are single line by default
    makeSingleLine()
    textColor = UIColor.black

    // we want to be able to force unwrap
    text = ""
  }

  open var view: UIView {
    get {
      return _wrapper
    }
  }

  @objc open var alignment: NSTextAlignment {
    get {
      return _field.textAlignment
    }
    set(alignment) {
      _field.textAlignment = alignment
      _view.textAlignment = alignment
    }
  }

  @objc open var backgroundColor: UIColor? {
    get {
      return _field.backgroundColor
    }
    set(color) {
      _view.backgroundColor = color
      _field.backgroundColor = color
    }
  }

  @objc open var textColor: UIColor? {
    get {
      return _field.textColor
    }
    set(color) {
      _field.textColor = color
      _view.textColor = _empty ? kDefaultPlaceholderColor : color
    }
  }

  @objc open var font: UIFont {
    get {
      return _field.font!
    }
    set(font) {
      _view.font = font
      _field.font = font
    }
  }

  @objc open var placeholderText: String? {
    get {
      return _field.placeholder
    }
    set(text) {
      _field.placeholder = text
      if _empty {
        _view.text = text
      }
    }
  }

  @objc open var text: String? {
    get {
      return _multiLine ? _view.text: _field.text
    }
    set(text) {
      _field.text = text
      _view.text = text
    }
  }

  @objc var multiLine: Bool {
    get {
      return _multiLine
    }
    set(multiLine) {
      if _multiLine == multiLine {
        return  // nothing to do
      }
      if multiLine {
        makeMultiLine()
      } else {
        makeSingleLine()
      }
    }
  }

  @objc var numbersOnly: Bool {
    get {
      return _numbersOnly
    }
    set(acceptsNumbersOnly) {
      if acceptsNumbersOnly != _numbersOnly {
        _numbersOnly = acceptsNumbersOnly
        let keyboardType: UIKeyboardType = acceptsNumbersOnly ? .numberPad : .default
        _field.keyboardType = keyboardType
        _view.keyboardType = keyboardType
        _field.reloadInputViews()
        _view.reloadInputViews()
      }
    }
  }

  fileprivate func setEmpty(_ shouldEmpty: Bool) {
    _empty = shouldEmpty
    _view.text = _empty ? _field.placeholder: nil
    _view.textColor = _empty ? kDefaultPlaceholderColor : _field.textColor
  }

  private func makeMultiLine() {
    _field.removeFromSuperview()
    _wrapper.addSubview(_view)
    _wrapper.addConstraint(_view.heightAnchor.constraint(equalTo: _wrapper.heightAnchor))
    _wrapper.addConstraint(_view.widthAnchor.constraint(equalTo: _wrapper.widthAnchor))
    _wrapper.addConstraint(_view.topAnchor.constraint(equalTo: _wrapper.topAnchor))
    _wrapper.addConstraint(_view.leadingAnchor.constraint(equalTo: _wrapper.leadingAnchor))
    _multiLine = true
  }

  private func makeSingleLine() {
    _view.removeFromSuperview()
    _wrapper.addSubview(_field)
    _wrapper.addConstraint(_field.heightAnchor.constraint(equalTo: _wrapper.heightAnchor))
    _wrapper.addConstraint(_field.widthAnchor.constraint(equalTo: _wrapper.widthAnchor))
    _wrapper.addConstraint(_field.topAnchor.constraint(equalTo: _wrapper.topAnchor))
    _wrapper.addConstraint(_field.leadingAnchor.constraint(equalTo: _wrapper.leadingAnchor))
    _multiLine = false
  }

  func textViewDidBeginEditing(_ textView: UITextView) {
    if _empty {
      setEmpty(false)
    }
  }

  func textViewDidEndEditing(_ textView: UITextView) {
    _field.text = textView.text
    if textView.text.isEmpty {
      setEmpty(true)
    }
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    if _empty {
      setEmpty(false)
    }
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    _view.text = textField.text
    if textField.text?.isEmpty ?? true {
      setEmpty(true)
    }
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    processText(string, range: range)
    if let cursorLocation = textField.position(from: textField.beginningOfDocument, offset: (range.location + string.count)) {
      textField.selectedTextRange = textField.textRange(from: cursorLocation, to: cursorLocation)
    }
    return false
  }

  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    processText(text, range: range)
    if let cursorLocation = textView.position(from: textView.beginningOfDocument, offset: (range.location + text.count)) {
      textView.selectedTextRange = textView.textRange(from: cursorLocation, to: cursorLocation)
    }
    return false
  }

  fileprivate func processText(_ newText: String, range: NSRange) {
    if let range = Range(range, in: _field.text!) {
      _field.text?.replaceSubrange(range, with: ensureNumber(newText))
    }
    if let range = Range(range, in: _view.text!) {
      _view.text?.replaceSubrange(range, with: ensureNumber(newText))
    }
  }

  fileprivate func ensureNumber(_ text: String) -> String {
    let result = _numbersOnly ? text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression): text
    return result
  }

  @objc func dismissKeyboard() {
    _view.endEditing(true)
    _field.endEditing(true)
  }
}

open class TextBox: TextBoxBase {
  fileprivate let _adapter = TextBoxAdapter()
  fileprivate var _acceptsNumbersOnly = false
  fileprivate var _colorSet = false
  fileprivate var _empty = true

  @objc public init(_ parent: ComponentContainer) {
    super.init(parent, _adapter)
    MultiLine = false
  }

  // MARK: TextBox Properties
  @objc open var NumbersOnly: Bool {
    get {
      return _adapter._numbersOnly
    }
    set(acceptsNumbersOnly) {
      _adapter._numbersOnly = acceptsNumbersOnly
    }
  }

  @objc open override var Height: Int32 {
    didSet {
      _adapter._view.isScrollEnabled = Height != kLengthPreferred
    }
  }

  @objc public var MultiLine: Bool {
    get {
      return _adapter.multiLine
    }
    set(multiLine) {
      _adapter.multiLine = multiLine
    }
  }

  // MARK: TextBox Methods
  @objc public func HideKeyboard() {
    _adapter._view.resignFirstResponder()
  }
}
