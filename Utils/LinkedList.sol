pragma solidity ^0.4.21;

contract LinkedList {

    struct Element {
        uint previous;
        uint next;

        address data;
    }

    uint public size;
    uint public tail;
    uint public head;
    mapping(uint => Element) elements;
    mapping(address => uint) elementLocation;

    function addItem(address _newItem) public returns (bool) {
        Element memory elem = Element(0, 0, _newItem);

        if (size == 0) {
            head = 1;
        } else {
            elements[tail].next = tail + 1;
            elem.previous = tail;
        }

        elementLocation[_newItem] = tail + 1;
        elements[tail + 1] = elem;
        size++;
        tail++;
        return true;
    }

    function removeItem(address _item) public returns (bool) {
        uint key;
        if (elementLocation[_item] == 0) {
            return false;
        }else {
            key = elementLocation[_item];
        }

        if (size == 1) {
            tail = 0;
            head = 0;
        }else if (key == head) {
            head = elements[head].next;
        }else if (key == tail) {
            tail = elements[tail].previous;
            elements[tail].next = 0;
        }else {
            elements[key - 1].next = elements[key].next;
            elements[key + 1].previous = elements[key].previous;
        }

        size--;
        delete elements[key];
        elementLocation[_item] = 0;
        return true;
    }

    function getAllElements() constant public returns(address[]) {
        address[] memory tempElementArray = new address[](size);
        uint cnt = 0;
        uint currentElemId = head;
        while (cnt < size) {
            tempElementArray[cnt] = elements[currentElemId].data;
            currentElemId = elements[currentElemId].next;
            cnt += 1;
        }
        return tempElementArray;
    }

    function getElementAt(uint _index) constant public returns (address) {
        return elements[_index].data;
    }

    function getElementLocation(address _element) constant public returns (uint) {
        return elementLocation[_element];
    }

    function getNextElement(uint _currElementId) constant public returns (uint) {
        return elements[_currElementId].next;
    }
}