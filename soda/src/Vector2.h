//
//  Vector2.h
//  Represents a 2d vector in Soda.
//

struct Vector2 {
    Vector2() : Vector2(0, 0) {}
    explicit Vector2(double xy) : x(xy), y(xy) {}
    Vector2(double x, double y) : x(x), y(y) {}

    Vector2(const Vector2&) = default;
    Vector2& operator=(const Vector2&) = default;

    Vector2(Vector2&&) = default;
    Vector2& operator=(Vector2&&) = default;

    // Comparison operators
	bool operator == (const Vector2& V) const { return x == V.x && y == V.y; }
	bool operator != (const Vector2& V) const { return x != V.x || y != V.y; }

    // Assignment operators
    Vector2& operator+= (const Vector2& rhs) { x += rhs.x; y += rhs.y; return *this; }
    Vector2& operator-= (const Vector2& rhs) { x -= rhs.x; y -= rhs.y; return *this; }
    Vector2& operator*= (double scalar) { x *= scalar; y *= scalar; return *this; }
    Vector2& operator/= (double scalar) { x /= scalar; y /= scalar; return *this; }

    // Unary operators
    Vector2 operator+ () const { return *this; }
    Vector2 operator- () const { return Vector2(-x, -y); }
            
    // Factory function
	static Vector2 Zero() { return Vector2(0.0, 0.0); }
			
	double x;
	double y;
};

// Binary operators
Vector2 operator+ (const Vector2& v1, const Vector2& v2);
Vector2 operator- (const Vector2& v1, const Vector2& v2);
Vector2 operator* (const Vector2& v1, float scalar);
Vector2 operator/ (const Vector2& v1, float scalar);
